# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::TrackBlockedRequestJob, type: :job do
  let(:ip)           { "1.2.3.4" }
  let(:user_agent)   { "ScannerBot/1.0" }
  let(:path)         { "/secret" }
  let(:http_method)  { "GET" }
  let(:block_reason) { Trackguard::BlockedRequest::REASON_SCANNER }

  def perform
    described_class.perform_now(
      ip: ip,
      user_agent: user_agent,
      path: path,
      http_method: http_method,
      block_reason: block_reason
    )
  end

  it "creates a BlockedRequest record" do
    expect { perform }.to change(Trackguard::BlockedRequest, :count).by(1)
  end

  it "sets the correct attributes on the blocked request" do
    perform
    record = Trackguard::BlockedRequest.last
    expect(record.path).to eq("/secret")
    expect(record.user_agent).to eq("ScannerBot/1.0")
    expect(record.http_method).to eq("GET")
    expect(record.block_reason).to eq(Trackguard::BlockedRequest::REASON_SCANNER)
  end

  it "creates a visitor for a new IP" do
    expect { perform }.to change(Trackguard::Visitor, :count).by(1)
  end

  it "reuses an existing visitor" do
    create(:visitor, ip: ip)
    expect { perform }.not_to change(Trackguard::Visitor, :count)
  end

  it "updates last_seen_at on the visitor" do
    visitor = create(:visitor, ip: ip, last_seen_at: 1.hour.ago)
    perform
    expect(visitor.reload.last_seen_at).to be > 1.minute.ago
  end

  it "links the blocked request to the visitor" do
    perform
    visitor = Trackguard::Visitor.find_by(ip: ip)
    expect(Trackguard::BlockedRequest.last.visitor).to eq(visitor)
  end
end
