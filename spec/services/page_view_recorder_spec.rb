require "rails_helper"

DEFAULT_PARAMS = {
  path: "/blog",
  ip: "1.2.3.4",
  user_agent: "Mozilla/5.0",
  referer: "https://example.com",
  session_id: "abc123",
  trace_id: "trace-xyz"
}.freeze

RSpec.describe Trackguard::PageViewRecorder do
  def call(**overrides)
    Trackguard::PageViewRecorder.call(**DEFAULT_PARAMS, **overrides)
  end

  it "enqueues Trackguard::TrackPageViewJob with correct args for valid page view" do
    expect do
      call
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(
                                                                  path: "/blog",
                                                                  ip: "1.2.3.4",
                                                                  user_agent: "Mozilla/5.0",
                                                                  referer: "https://example.com",
                                                                  session_id: "abc123",
                                                                  trace_id: "trace-xyz",
                                                                  source: nil
                                                                ))
  end

  it "does not enqueue job for admin path" do
    expect do
      call(path: "/admin/posts")
    end.not_to have_enqueued_job
  end

  it "does not enqueue job for blank path" do
    expect do
      call(path: "")
    end.not_to have_enqueued_job
  end

  it "does not enqueue job for nil path" do
    expect do
      call(path: nil)
    end.not_to have_enqueued_job
  end

  it "passes source to Trackguard::TrackPageViewJob when provided" do
    expect do
      call(source: "linkedin")
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: "linkedin"))
  end

  it "passes nil source when not provided" do
    expect do
      call
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: nil))
  end

  it "normalizes blank source to nil" do
    expect do
      call(source: "   ")
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: nil))
  end

  it "passes http_method to TrackPageViewJob when provided" do
    expect do
      call(http_method: "GET")
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(http_method: "GET"))
  end

  it "passes nil http_method when not provided" do
    expect do
      call
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(http_method: nil))
  end

  context "when user agent is on the blocked list" do
    before do
      Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY)
      create(:blocked_user_agent, pattern: "AhrefsBot")
    end

    it "does not enqueue for a matching user agent" do
      expect do
        call(user_agent: "AhrefsBot/7.0")
      end.not_to have_enqueued_job
    end

    it "does not enqueue for a case-insensitive match" do
      expect do
        call(user_agent: "ahrefsbot/7.0")
      end.not_to have_enqueued_job
    end

    it "still enqueues for a non-blocked user agent" do
      expect do
        call(user_agent: "Mozilla/5.0 Chrome/124")
      end.to have_enqueued_job(Trackguard::TrackPageViewJob)
    end
  end
end
