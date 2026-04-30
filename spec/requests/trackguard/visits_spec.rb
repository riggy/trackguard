require "rails_helper"

RSpec.describe "GET /admin/visits", type: :request do
  after { Trackguard.instance_variable_set(:@authenticate_admin_with, nil) }

  it "returns 200 with the default no-op auth" do
    get "/admin/visits"
    expect(response).to have_http_status(:ok)
  end

  it "runs the configured authenticate_admin_with proc" do
    Trackguard.authenticate_admin_with = proc { head :unauthorized }
    get "/admin/visits"
    expect(response).to have_http_status(:unauthorized)
  end

  context "with page view data" do
    let!(:pv1) { create(:page_view, path: "/home",  created_at: 1.hour.ago) }
    let!(:pv2) { create(:page_view, path: "/about", created_at: 2.hours.ago) }

    before { get "/admin/visits" }

    it "renders page view paths" do
      expect(response.body).to include("/home")
      expect(response.body).to include("/about")
    end

    it "shows the total count" do
      expect(response.body).to include("2")
    end

    it "shows visits in descending order" do
      expect(response.body.index("/home")).to be < response.body.index("/about")
    end
  end

  context "pagination" do
    before { stub_const("Trackguard::Admin::VisitsController::PER_PAGE", 2) }

    let!(:pv1) { create(:page_view, path: "/p1", created_at: 1.hour.ago) }
    let!(:pv2) { create(:page_view, path: "/p2", created_at: 2.hours.ago) }
    let!(:pv3) { create(:page_view, path: "/p3", created_at: 3.hours.ago) }

    it "shows first page results on page 1" do
      get "/admin/visits", params: { page: 1 }
      expect(response.body).to include("/p1")
      expect(response.body).not_to include("/p3")
    end

    it "shows second page results on page 2" do
      get "/admin/visits", params: { page: 2 }
      expect(response.body).to include("/p3")
      expect(response.body).not_to include("/p1")
    end
  end
end
