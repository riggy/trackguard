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
                         .select(:visitor_id, :session_id, :referer, :path, :trace_id, :tracking_layer)
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
      return if whitelisted?(visitor)

      name = name_from_ua(visitor.user_agent)

      if visitor.suspicious?
        new_views = PageView
                    .where(visitor: visitor)
                    .where("created_at > ?", visitor.suspicious_since_at)
                    .select(:tracking_layer, :trace_id)
        result = evaluate_suspicious_escalation(visitor, new_views)
        return if %i[blocked recovered].include?(result)
      elsif views.any?(&:backend_layer?) && views.none?(&:js_layer?)
        mark_suspicious!(visitor, name)
      end

      if count >= HARD_FLAG_THRESHOLD
        mark_blocked!(visitor, "#{count} page views in 24h (hard flag threshold)", name: name)
        return
      end

      if (reason = ua_flag_reason(visitor.user_agent))
        mark_blocked!(visitor, reason, name: name)
        return
      end

      if (path = probe_path_hit(views))
        mark_blocked!(visitor, "probe path hit: #{path}", name: name)
        return
      end

      # Don't flag casual visitors with very few views — on a single-page site,
      # legitimate users naturally hit only "/" once or twice.
      return if count < MIN_VIEWS

      if views.all? { |pv| pv.session_id.nil? && pv.referer.nil? } && views.map(&:path).uniq.size == 1
        mark_blocked!(visitor, "no session, no referrer, single path hit", name: name)
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

      mark_blocked!(visitor, reasons.join("; "), name: name)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def evaluate_suspicious_escalation(visitor, new_views)
      return :unchanged if new_views.empty?

      js_ids = new_views.select { |pv| pv.tracking_layer == "js" }.map(&:trace_id).compact

      if any_unpaired_backend?(new_views, js_ids)
        mark_blocked!(visitor, "continued backend-only visits since suspicious flag")
        :blocked
      elsif paired_backend_trace_ids(new_views, js_ids).any?
        mark_normal!(visitor)
        :recovered
      else
        :unchanged
      end
    end

    def any_unpaired_backend?(views, js_trace_ids)
      views.any? { |pv| pv.backend_layer? && !js_trace_ids.include?(pv.trace_id) }
    end

    def paired_backend_trace_ids(views, js_trace_ids)
      views.select(&:backend_layer?).map(&:trace_id).compact & js_trace_ids
    end

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
          mark_blocked!(visitor, "trace_id shared across multiple visitors (cross-visitor bot detected)",
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

    def mark_suspicious!(visitor, name)
      return if visitor.suspicious? || visitor.blocked?

      visitor.update!(suspicious_state: "suspicious", suspicious_since_at: Time.current, name: name)
    end

    def mark_normal!(visitor)
      return if visitor.normal? || visitor.blocked?

      visitor.update!(suspicious_state: "normal", suspicious_since_at: nil)
    end

    def mark_blocked!(visitor, reason, name: nil)
      visitor.update!(
        suspicious_state: "blocked",
        flagged_at: Time.current,
        flag_reason: reason,
        flagged_by: "Recurring Job",
        suspicious_since_at: nil,
        name: name
      )
    end

    protected

    def whitelisted?(visitor)
      wl = visitor.whitelisted_ip
      unless wl
        wl = WhitelistedIp.active.find_by(ip: visitor.ip)
        wl&.update!(visitor: visitor)
      end
      wl&.active?
    end

    private

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
