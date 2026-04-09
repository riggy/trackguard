module Trackguard
  module PageTracker
    extend ActiveSupport::Concern

    module ClassMethods
      def track_page_views(**options)
        after_action :track_page_view, **options
      end
    end

    private

    def track_page_view
      return unless request.get? || request.head?
      return unless request.format.html?

      PageViewRecorder.call(
        path:       request.path,
        ip:         request.remote_ip,
        user_agent: request.user_agent.to_s,
        referer:    request.referer,
        session_id: session.id.to_s,
        trace_id:   @trace_id,
        source:     extract_source
      )
    end

    def extract_source
      raw = params[:ref].presence || params[:utm_source].presence
      raw&.strip&.downcase&.first(64)
    end
  end
end
