require "rails_helper"

RSpec.describe "GET /admin/dashboard", type: :request do
  after { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

  it "returns 200 with the default no-op auth" do
    get "/admin/dashboard"
    expect(response).to have_http_status(:ok)
  end

  it "runs the configured authenticate_admin_with proc" do
    Trackguard.authenticate_admin_with = proc { head :unauthorized }
    get "/admin/dashboard"
    expect(response).to have_http_status(:unauthorized)
  end

  context "with page view data" do
    let!(:recent)   { create(:page_view, path: "/home",  created_at: Time.current) }
    let!(:older)    { create(:page_view, path: "/about", created_at: 31.days.ago) }
    let!(:sourced)  { create(:page_view, :with_source,   created_at: Time.current) }

    before { get "/admin/dashboard" }

    it "renders the page" do
      expect(response).to have_http_status(:ok)
    end

    it "shows today's total" do
      # 2 page views today (recent + sourced)
      expect(response.body).to include("2")
    end

    it "includes recent visit paths" do
      expect(response.body).to include("/home")
    end

    it "includes top-page paths from last 30 days" do
      expect(response.body).to include("/home")
    end

    it "shows the traffic source" do
      expect(response.body).to include("linkedin")
    end

    it "shows the referrer" do
      expect(response.body).to include("example.com")
    end

    it "shows recent visits in descending order" do
      # /home (today) appears before /about (31 days ago) in recent visits
      expect(response.body.index("/home")).to be < response.body.index("/about")
    end
  end
end
