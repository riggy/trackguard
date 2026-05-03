require "rails_helper"

RSpec.describe "Admin whitelist actions", type: :request do
  let!(:visitor) { create(:visitor) }

  describe "PATCH /admin/visitors/whitelist" do
    it "whitelists the visitor by id" do
      patch "/admin/visitors/whitelist", params: { id: visitor.id }
      expect(Trackguard::WhitelistedIp.active.exists?(ip: visitor.ip)).to be true
    end

    it "whitelists the visitor by ip" do
      patch "/admin/visitors/whitelist", params: { ip: visitor.ip }
      expect(Trackguard::WhitelistedIp.active.exists?(ip: visitor.ip)).to be true
    end

    it "defaults expires_at to 7 days from now" do
      patch "/admin/visitors/whitelist", params: { id: visitor.id }
      record = Trackguard::WhitelistedIp.find_by!(ip: visitor.ip)
      expect(record.expires_at).to be_within(5.seconds).of(7.days.from_now)
    end

    it "accepts a custom expires_at" do
      future = 30.days.from_now
      patch "/admin/visitors/whitelist", params: { id: visitor.id, expires_at: future.iso8601 }
      record = Trackguard::WhitelistedIp.find_by!(ip: visitor.ip)
      expect(record.expires_at).to be_within(5.seconds).of(future)
    end

    it "updates an existing expired record rather than creating a new one" do
      existing = create(:whitelisted_ip, :expired, ip: visitor.ip, visitor: visitor)
      patch "/admin/visitors/whitelist", params: { id: visitor.id }
      expect(Trackguard::WhitelistedIp.where(ip: visitor.ip).count).to eq(1)
      expect(existing.reload.expires_at).to be > Time.current
    end

    it "redirects after whitelisting" do
      patch "/admin/visitors/whitelist", params: { id: visitor.id }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /admin/visitors/unwhitelist" do
    let!(:whitelist_entry) { create(:whitelisted_ip, ip: visitor.ip, visitor: visitor) }

    it "removes the whitelist entry by id" do
      patch "/admin/visitors/unwhitelist", params: { id: visitor.id }
      expect(Trackguard::WhitelistedIp.exists?(ip: visitor.ip)).to be false
    end

    it "removes the whitelist entry by ip" do
      patch "/admin/visitors/unwhitelist", params: { ip: visitor.ip }
      expect(Trackguard::WhitelistedIp.exists?(ip: visitor.ip)).to be false
    end

    it "redirects after unwhitelisting" do
      patch "/admin/visitors/unwhitelist", params: { id: visitor.id }
      expect(response).to have_http_status(:redirect)
    end

    it "responds with 404 JSON when visitor is not whitelisted" do
      whitelist_entry.destroy!
      patch "/admin/visitors/unwhitelist",
            params: { id: visitor.id },
            headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:not_found)
    end
  end

  context "with bearer token authentication" do
    before { Trackguard.api_token = "secret-token" }
    after  { Trackguard.instance_variable_set(:@api_token, nil) }

    context "and admin auth configured to reject" do
      before { Trackguard.authenticate_admin_with = proc { head :unauthorized } }
      after  { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

      it "allows whitelist with a valid bearer token" do
        patch "/admin/visitors/whitelist",
              params: { id: visitor.id },
              headers: { "Authorization" => "Bearer secret-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:ok)
        expect(Trackguard::WhitelistedIp.active.exists?(ip: visitor.ip)).to be true
      end

      it "allows unwhitelist with a valid bearer token" do
        create(:whitelisted_ip, ip: visitor.ip, visitor: visitor)
        patch "/admin/visitors/unwhitelist",
              params: { id: visitor.id },
              headers: { "Authorization" => "Bearer secret-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:ok)
      end

      it "rejects whitelist with an invalid bearer token" do
        patch "/admin/visitors/whitelist",
              params: { id: visitor.id },
              headers: { "Authorization" => "Bearer wrong-token", "Accept" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects whitelist with no token" do
        patch "/admin/visitors/whitelist",
              params: { id: visitor.id },
              headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
