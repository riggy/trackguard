module Trackguard
  class DetectSuspiciousVisitorsJob < ApplicationJob
    queue_as :default

    HARD_FLAG_THRESHOLD  = 50
    HIGH_VOLUME_MIN      = 20
    MEDIUM_VOLUME_MIN    = 10
    FLAG_SCORE_THRESHOLD = 5
    MIN_VIEWS            = 3

    WEIGHTS = {
      high_volume: 4,
      medium_volume: 2,
      no_session: 3
    }.freeze

    def perform
      recent_cutoff = 24.hours.ago

      flag_shared_trace_id_visitors(recent_cutoff)

      views_by_visitor = PageView
                         .where(created_at: recent_cutoff..)
                         .joins(:visitor)
                         .merge(Visitor.unflagged)
                         .preload(visitor: :whitelisted_ip)
                         .select(:visitor_id, :session_id, :referer, :path, :trace_id)
                         .group_by(&:visitor)

      return if views_by_visitor.empty?

      views_by_visitor.each do |visitor, views|
        analyze_visitor(visitor, views)
      end
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def analyze_visitor(visitor, views)
      count = views.size
      return if count.zero?
      return if visitor.whitelisted_ip&.active?

      name = name_from_ua(visitor.user_agent)

      if count >= HARD_FLAG_THRESHOLD
        flag!(visitor, "#{count} page views in 24h (hard flag threshold)", name: name)
        return
      end

      if (reason = ua_flag_reason(visitor.user_agent))
        flag!(visitor, reason, name: name)
        return
      end

      if (path = probe_path_hit(views))
        flag!(visitor, "probe path hit: #{path}", name: name)
        return
      end

      # Don't flag casual visitors with very few views — on a single-page site,
      # legitimate users naturally hit only "/" once or twice.
      return if count < MIN_VIEWS

      if views.all? { |pv| pv.session_id.nil? && pv.referer.nil? } && views.map(&:path).uniq.size == 1
        flag!(visitor, "no session, no referrer, single path hit", name: name)
        return
      end

      score   = 0
      reasons = []

      if count >= HIGH_VOLUME_MIN
        score += WEIGHTS[:high_volume]
        reasons << "#{count} page views in 24h"
      elsif count >= MEDIUM_VOLUME_MIN
        score += WEIGHTS[:medium_volume]
        reasons << "#{count} page views in 24h"
      end

      if blank_ratio(views, :session_id) > 0.8
        score += WEIGHTS[:no_session]
        reasons << "#{pct(views, :session_id)}% of views had no session"
      end

      return if score < FLAG_SCORE_THRESHOLD

      flag!(visitor, reasons.join("; "), name: name)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def flag_shared_trace_id_visitors(cutoff)
      shared = PageView
               .where(created_at: cutoff..)
               .where.not(trace_id: nil)
               .group(:trace_id)
               .having("COUNT(DISTINCT visitor_id) > 1")
               .pluck(:trace_id)

      return if shared.empty?

      Visitor
        .unflagged
        .joins("LEFT OUTER JOIN trackguard_whitelisted_ips wi ON wi.visitor_id = trackguard_visitors.id")
        .joins(:page_views)
        .where(trackguard_visits: { trace_id: shared, created_at: cutoff.. })
        .where("wi.id IS NULL OR wi.expires_at <= ?", Time.current)
        .distinct
        .each do |visitor|
          flag!(visitor, "trace_id shared across multiple visitors (cross-visitor bot detected)",
                name: name_from_ua(visitor.user_agent))
        end
    end

    def probe_path_hit(views)
      views.find { |pv| BlockedPath.blocked?(pv.path) }&.path
    end

    def ua_flag_reason(user_agent)
      return "blank or minimal user-agent" if user_agent.blank? || user_agent.to_s.length < 10
      return "bare Mozilla/5.0 user-agent" if user_agent.strip == "Mozilla/5.0"
      return "malformed user-agent (quoted)" if user_agent.start_with?('"')

      "malformed user-agent (duplicate)" if user_agent.scan("Mozilla/5.0").size > 1
    end

    def flag!(visitor, reason, name: nil)
      visitor.update!(flagged_at: Time.current, flag_reason: reason, flagged_by: "claw:auto", name: name)
    end

    def name_from_ua(user_agent)
      BlockedUserAgent.matching_pattern(user_agent)
    end

    def blank_ratio(views, attr)
      views.count { |v| v.public_send(attr).blank? }.to_f / views.size
    end

    def pct(views, attr)
      (blank_ratio(views, attr) * 100).round
    end
  end
end
