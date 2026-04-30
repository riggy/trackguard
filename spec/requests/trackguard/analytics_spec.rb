require "rails_helper"

RSpec.describe "GET /admin/analytics", type: :request do
  after { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

  it "returns 200 with the default no-op auth" do
    get "/admin/analytics"
    expect(response).to have_http_status(:ok)
  end

  it "runs the configured authenticate_admin_with proc" do
    Trackguard.authenticate_admin_with = proc { head :unauthorized }
    get "/admin/analytics"
    expect(response).to have_http_status(:unauthorized)
  end

  it "responds with JSON" do
    get "/admin/analytics"
    expect(response.content_type).to include("application/json")
  end

  context "with analytics data" do
    let!(:recent)  { create(:page_view, path: "/home",  created_at: Time.current) }
    let!(:older)   { create(:page_view, path: "/about", created_at: 31.days.ago) }
    let!(:within)  { create(:page_view, path: "/blog",  created_at: 5.days.ago) }
    let!(:sourced) { create(:page_view, :with_source,   created_at: Time.current) }

    before { get "/admin/analytics" }

    it "includes totals keys" do
      body = JSON.parse(response.body)
      expect(body).to include("totals", "top_pages", "top_referrers", "top_sources", "recent")
    end

    it "returns today count" do
      body = JSON.parse(response.body)
      expect(body["totals"]["today"]).to eq(2)
    end

    it "includes recent visit fields" do
      body = JSON.parse(response.body)
      entry = body["recent"].first
      expect(entry.keys).to include("path", "ip", "flagged_at", "flagged_by", "whitelisted",
                                    "user_agent", "session_id", "trace_id", "referer", "source", "created_at")
    end

    it "orders recent visits newest first" do
      body = JSON.parse(response.body)
      paths = body["recent"].map { |pv| pv["path"] }
      expect(paths.index("/home")).to be < paths.index("/blog")
    end

    it "excludes page views older than 30 days from top_pages" do
      body = JSON.parse(response.body)
      expect(body["top_pages"].keys).not_to include("/about")
    end

    it "excludes page views older than 30 days from recent" do
      body = JSON.parse(response.body)
      expect(body["recent"].map { |pv| pv["path"] }).not_to include("/about")
    end
  end

  context "with bearer token authentication" do
    before { Trackguard.api_token = "secret-token" }
    after  { Trackguard.instance_variable_set(:@api_token, nil) }

    context "and admin auth configured to reject" do
      before { Trackguard.authenticate_admin_with = proc { head :unauthorized } }

      it "allows access with a valid bearer token" do
        get "/admin/analytics", headers: { "Authorization" => "Bearer secret-token" }
        expect(response).to have_http_status(:ok)
      end

      it "rejects with an invalid bearer token" do
        get "/admin/analytics", headers: { "Authorization" => "Bearer wrong-token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects with no token" do
        get "/admin/analytics"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
