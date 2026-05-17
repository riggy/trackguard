# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::Adapters::Base do
  subject(:adapter) { described_class.new }

  it { expect { adapter.blocked_user_agent?("x") }.to raise_error(NotImplementedError) }
  it { expect { adapter.whitelisted_ip?("1.2.3.4") }.to raise_error(NotImplementedError) }
  it { expect { adapter.flagged_visitor?("1.2.3.4") }.to raise_error(NotImplementedError) }

  it "raises NotImplementedError from track_page_view (abstract subclass methods unimplemented)" do
    expect do
      adapter.track_page_view(
        path: "/", ip: "1.2.3.4", user_agent: "Mozilla", referer: nil,
        session_id: nil, trace_id: nil, source: nil, initial: false, http_method: "GET"
      )
    end.to raise_error(NotImplementedError)
  end

  it do
    expect do
      adapter.track_blocked_request(
        ip: "1.2.3.4", user_agent: "bot", path: "/", http_method: "GET", block_reason: "test"
      )
    end.to raise_error(NotImplementedError)
  end
end
