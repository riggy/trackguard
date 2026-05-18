require "rails_helper"

RSpec.describe "Admin blocked paths", type: :request do
  describe "GET /admin/blocked_paths" do
    it "returns 200" do
      get "/admin/blocked_paths"
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get "/admin/blocked_paths"
      expect(JSON.parse(response.body)).to be_an(Array)
    end

    it "returns patterns sorted alphabetically" do
      create(:blocked_path, pattern: "/z-probe")
      create(:blocked_path, pattern: "/a-probe")
      get "/admin/blocked_paths"
      expect(JSON.parse(response.body)).to eq(%w[/a-probe /z-probe])
    end

    it "runs the configured authenticate_admin_with proc" do
      Trackguard.authenticate_admin_with = proc { head :unauthorized }
      get "/admin/blocked_paths"
      expect(response).to have_http_status(:unauthorized)
      Trackguard.instance_variable_set(:@authenticate_admin_with, nil)
    end
  end

  describe "POST /admin/blocked_paths" do
    it "creates a new blocked path and returns ok" do
      post "/admin/blocked_paths", params: { pattern: "/.env" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ "status" => "ok", "pattern" => "/.env" })
    end

    it "is idempotent — does not create a duplicate" do
      create(:blocked_path, pattern: "/.env")
      expect do
        post "/admin/blocked_paths", params: { pattern: "/.env" }
      end.not_to change(Trackguard::BlockedPath, :count)
      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when pattern param is missing" do
      post "/admin/blocked_paths", params: {}
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["status"]).to eq("error")
    end

    it "runs the configured authenticate_admin_with proc" do
      Trackguard.authenticate_admin_with = proc { head :unauthorized }
      post "/admin/blocked_paths", params: { pattern: "/wp-login.php" }
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
        get "/admin/blocked_paths",
            headers: { "Authorization" => "Bearer secret-token" }
        expect(response).to have_http_status(:ok)
      end

      it "allows create with a valid bearer token" do
        post "/admin/blocked_paths",
             params: { pattern: "/.git/config" },
             headers: { "Authorization" => "Bearer secret-token" }
        expect(response).to have_http_status(:ok)
      end

      it "rejects with an invalid bearer token" do
        get "/admin/blocked_paths",
            headers: { "Authorization" => "Bearer wrong-token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects with no token" do
        get "/admin/blocked_paths"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
