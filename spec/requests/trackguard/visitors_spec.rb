require "rails_helper"

RSpec.describe "Admin visitor flag actions", type: :request do
  let!(:visitor) { create(:visitor) }

  describe "PATCH /admin/visitors/flag" do
    it "flags the visitor by id" do
      patch "/admin/visitors/flag", params: { id: visitor.id, flag_reason: "suspicious" }
      expect(visitor.reload.flagged_at).not_to be_nil
    end

    it "flags the visitor by ip" do
      patch "/admin/visitors/flag", params: { ip: visitor.ip, flag_reason: "suspicious" }
      expect(visitor.reload.flagged_at).not_to be_nil
    end

    it "sets flag_reason from params" do
      patch "/admin/visitors/flag", params: { id: visitor.id, flag_reason: "scraper" }
      expect(visitor.reload.flag_reason).to eq("scraper")
    end

    it "sets flagged_by to the first FLAGGED_BY value" do
      patch "/admin/visitors/flag", params: { id: visitor.id }
      expect(visitor.reload.flagged_by).to eq(Trackguard::Visitor::FLAGGED_BY.first)
    end

    it "accepts a blank flag_reason" do
      patch "/admin/visitors/flag", params: { id: visitor.id, flag_reason: "" }
      expect(visitor.reload.flag_reason).to be_nil
    end

    it "sets name from params" do
      patch "/admin/visitors/flag", params: { id: visitor.id, name: "Scrapy" }
      expect(visitor.reload.name).to eq("Scrapy")
    end

    it "treats blank name as nil when no BlockedUserAgent pattern matches" do
      patch "/admin/visitors/flag", params: { id: visitor.id, name: "" }
      expect(visitor.reload.name).to be_nil
    end

    it "derives name from BlockedUserAgent when name param is absent" do
      Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY)
      create(:blocked_user_agent, pattern: "Chrome")
      patch "/admin/visitors/flag", params: { id: visitor.id }
      expect(visitor.reload.name).to eq("Chrome")
    end

    it "derives name from BlockedUserAgent when name param is blank" do
      Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY)
      create(:blocked_user_agent, pattern: "Chrome")
      patch "/admin/visitors/flag", params: { id: visitor.id, name: "" }
      expect(visitor.reload.name).to eq("Chrome")
    end

    it "prefers explicit name param over auto-detection" do
      Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY)
      create(:blocked_user_agent, pattern: "Chrome")
      patch "/admin/visitors/flag", params: { id: visitor.id, name: "custom-name" }
      expect(visitor.reload.name).to eq("custom-name")
    end

    it "redirects after flagging" do
      patch "/admin/visitors/flag", params: { id: visitor.id }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /admin/visitors/unflag" do
    let!(:visitor) { create(:visitor, :flagged) }

    it "unflags the visitor by id" do
      patch "/admin/visitors/unflag", params: { id: visitor.id }
      expect(visitor.reload.flagged_at).to be_nil
    end

    it "unflags the visitor by ip" do
      patch "/admin/visitors/unflag", params: { ip: visitor.ip }
      expect(visitor.reload.flagged_at).to be_nil
    end

    it "clears flag_reason and flagged_by" do
      patch "/admin/visitors/unflag", params: { id: visitor.id }
      v = visitor.reload
      expect(v.flag_reason).to be_nil
      expect(v.flagged_by).to be_nil
    end

    it "preserves name after unflagging" do
      visitor.update!(name: "Scrapy")
      patch "/admin/visitors/unflag", params: { id: visitor.id }
      expect(visitor.reload.name).to eq("Scrapy")
    end

    it "redirects after unflagging" do
      patch "/admin/visitors/unflag", params: { id: visitor.id }
      expect(response).to have_http_status(:redirect)
    end
  end

  context "with bearer token authentication" do
    before { Trackguard.local_api_token = "secret-token" }
    after  { Trackguard.instance_variable_set(:@local_api_token, nil) }

    context "and admin auth configured to reject" do
      before { Trackguard.authenticate_admin_with = proc { head :unauthorized } }
      after  { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

      it "allows flag with a valid bearer token" do
        patch "/admin/visitors/flag",
              params: { id: visitor.id, flag_reason: "bot" },
              headers: { "Authorization" => "Bearer secret-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:ok)
        expect(visitor.reload.flagged_at).not_to be_nil
      end

      it "allows unflag with a valid bearer token" do
        patch "/admin/visitors/unflag",
              params: { id: visitor.id },
              headers: { "Authorization" => "Bearer secret-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:ok)
      end

      it "rejects flag with an invalid bearer token" do
        patch "/admin/visitors/flag",
              params: { id: visitor.id, flag_reason: "bot" },
              headers: { "Authorization" => "Bearer wrong-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects flag with no token" do
        patch "/admin/visitors/flag",
              params: { id: visitor.id, flag_reason: "bot" },
              headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
