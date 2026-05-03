require "rails_helper"

RSpec.describe "Admin blocked user agents", type: :request do
  describe "GET /admin/blocked_user_agents" do
    it "returns 200" do
      get "/admin/blocked_user_agents"
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get "/admin/blocked_user_agents"
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it "returns patterns sorted alphabetically" do
      create(:blocked_user_agent, pattern: "ZZZBot")
      create(:blocked_user_agent, pattern: "AAABot")
      get "/admin/blocked_user_agents"
      expect(JSON.parse(response.body)).to eq(%w[AAABot ZZZBot])
    end

    it "runs the configured authenticate_admin_with proc" do
      Trackguard.authenticate_admin_with = proc { head :unauthorized }
      get "/admin/blocked_user_agents"
      expect(response).to have_http_status(:unauthorized)
      Trackguard.instance_variable_set(:@authenticate_admin_with, nil)
    end
  end

  describe "POST /admin/blocked_user_agents" do
    it "creates a new blocked user agent and returns ok" do
      post "/admin/blocked_user_agents", params: { pattern: "AhrefsBot" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "status" => "ok", "pattern" => "AhrefsBot" })
    end

    it "is idempotent — does not create a duplicate" do
      create(:blocked_user_agent, pattern: "AhrefsBot")
      expect do
        post "/admin/blocked_user_agents", params: { pattern: "AhrefsBot" }
      end.not_to change(Trackguard::BlockedUserAgent, :count)
      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when pattern param is missing" do
      post "/admin/blocked_user_agents", params: {}
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["status"]).to eq("error")
    end

    it "runs the configured authenticate_admin_with proc" do
      Trackguard.authenticate_admin_with = proc { head :unauthorized }
      post "/admin/blocked_user_agents", params: { pattern: "SemrushBot" }
      expect(response).to have_http_status(:unauthorized)
      Trackguard.instance_variable_set(:@authenticate_admin_with, nil)
    end
  end

  context "with bearer token authentication" do
    before { Trackguard.api_token = "secret-token" }
    after  { Trackguard.instance_variable_set(:@api_token, nil) }

    context "and admin auth configured to reject" do
      before { Trackguard.authenticate_admin_with = proc { head :unauthorized } }
      after  { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

      it "allows index with a valid bearer token" do
        get "/admin/blocked_user_agents",
            headers: { "Authorization" => "Bearer secret-token" }
        expect(response).to have_http_status(:ok)
      end

      it "allows create with a valid bearer token" do
        post "/admin/blocked_user_agents",
             params: { pattern: "SemrushBot" },
             headers: { "Authorization" => "Bearer secret-token" }
        expect(response).to have_http_status(:ok)
      end

      it "rejects with an invalid bearer token" do
        get "/admin/blocked_user_agents",
            headers: { "Authorization" => "Bearer wrong-token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects with no token" do
        get "/admin/blocked_user_agents"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
