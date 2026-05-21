require "rails_helper"

RSpec.describe Trackguard::TrackPageView do
  include ActiveSupport::Testing::TimeHelpers

  subject(:call) { described_class.call(**params) }

  let(:params) do
    {
      path: "/posts/hello",
      ip: "1.2.3.4",
      user_agent: "Mozilla/5.0",
      referer: "https://example.com",
      session_id: "abc123",
      trace_id: "trace-001",
      source: "google",
      http_method: "GET"
    }
  end

  describe "visitor find-or-create" do
    it "creates a visitor when the IP is new" do
      expect { call }.to change(Trackguard::Visitor, :count).by(1)
    end

    it "does not create a second visitor for the same IP" do
      create(:visitor, ip: "1.2.3.4")
      expect { call }.not_to change(Trackguard::Visitor, :count)
    end

    it "sets first_seen_at and last_seen_at on a new visitor" do
      freeze_time do
        call
        visitor = Trackguard::Visitor.find_by!(ip: "1.2.3.4")
        expect(visitor.first_seen_at).to eq(Time.current)
        expect(visitor.last_seen_at).to eq(Time.current)
      end
    end

    it "updates last_seen_at and user_agent on an existing visitor" do
      visitor = create(:visitor, ip: "1.2.3.4", user_agent: "OldAgent/1.0",
                                 last_seen_at: 1.hour.ago)
      freeze_time do
        call
        expect(visitor.reload.last_seen_at).to eq(Time.current)
        expect(visitor.reload.user_agent).to eq("Mozilla/5.0")
      end
    end
  end

  describe "page view creation" do
    it "creates a page view" do
      expect { call }.to change(Trackguard::PageView, :count).by(1)
    end

    it "stores a SHA-256 hash of session_id, not the raw value" do
      call
      hashed = Digest::SHA256.hexdigest("abc123")
      expect(Trackguard::PageView.last.session_id).to eq(hashed)
    end

    it "stores nil session_id when none is given" do
      described_class.call(**params, session_id: nil)
      expect(Trackguard::PageView.last.session_id).to be_nil
    end

    it "persists source, referer, and http_method" do
      call
      pv = Trackguard::PageView.last
      expect(pv.source).to eq("google")
      expect(pv.referer).to eq("https://example.com")
      expect(pv.http_method).to eq("GET")
    end

    it "associates the page view with the correct visitor" do
      call
      visitor = Trackguard::Visitor.find_by!(ip: "1.2.3.4")
      expect(Trackguard::PageView.last.visitor).to eq(visitor)
    end

    it "creates a new record on every call (no deduplication)" do
      described_class.call(**params)
      expect { described_class.call(**params) }.to change(Trackguard::PageView, :count).by(1)
    end

    it "persists tracking_layer: backend when called with tracking_layer: backend" do
      described_class.call(**params, tracking_layer: "backend")
      expect(Trackguard::PageView.last.tracking_layer).to eq("backend")
    end

    it "persists tracking_layer: js when called with tracking_layer: js" do
      described_class.call(**params, tracking_layer: "js")
      expect(Trackguard::PageView.last.tracking_layer).to eq("js")
    end
  end

  describe ".call class method" do
    it "delegates to #call on a new instance" do
      expect { call }.to change(Trackguard::PageView, :count).by(1)
    end
  end
end
