require "rails_helper"

RSpec.describe Trackguard::PageViewRecorder do
  DEFAULT_PARAMS = {
    path:       "/blog",
    ip:         "1.2.3.4",
    user_agent: "Mozilla/5.0",
    referer:    "https://example.com",
    session_id: "abc123",
    trace_id:   "trace-xyz"
  }.freeze

  def call(**overrides)
    Trackguard::PageViewRecorder.call(**DEFAULT_PARAMS.merge(overrides))
  end

  it "enqueues Trackguard::TrackPageViewJob with correct args for valid page view" do
    expect {
      call
    }.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(
      path:       "/blog",
      ip:         "1.2.3.4",
      user_agent: "Mozilla/5.0",
      referer:    "https://example.com",
      session_id: "abc123",
      trace_id:   "trace-xyz",
      source:     nil
    ))
  end

  it "does not enqueue job for Googlebot" do
    expect {
      call(user_agent: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")
    }.not_to have_enqueued_job
  end

  it "does not enqueue job for curl" do
    expect {
      call(user_agent: "curl/7.88.1")
    }.not_to have_enqueued_job
  end

  it "does not enqueue job for admin path" do
    expect {
      call(path: "/admin/posts")
    }.not_to have_enqueued_job
  end

  it "does not enqueue job for blank path" do
    expect {
      call(path: "")
    }.not_to have_enqueued_job
  end

  it "does not enqueue job for nil path" do
    expect {
      call(path: nil)
    }.not_to have_enqueued_job
  end

  it "passes source to Trackguard::TrackPageViewJob when provided" do
    expect {
      call(source: "linkedin")
    }.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: "linkedin"))
  end

  it "passes nil source when not provided" do
    expect {
      call
    }.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: nil))
  end

  it "normalizes blank source to nil" do
    expect {
      call(source: "   ")
    }.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: nil))
  end
end
