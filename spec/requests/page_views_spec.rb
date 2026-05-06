require "rails_helper"

RSpec.describe "POST /page_views", type: :request do
  def post_page_view(params: {}, user_agent: "Mozilla/5.0")
    post "/page_views",
         params: { path: "/blog", trace_id: "trace-001" }.merge(params),
         headers: { "User-Agent" => user_agent }
  end

  it "returns 204 no content" do
    post_page_view
    expect(response).to have_http_status(:no_content)
  end

  it "enqueues Trackguard::TrackPageViewJob for a valid request" do
    expect { post_page_view }.to have_enqueued_job(Trackguard::TrackPageViewJob)
  end


  it "passes ref param as source" do
    expect do
      post_page_view(params: { ref: "twitter" })
    end.to have_enqueued_job(Trackguard::TrackPageViewJob).with(hash_including(source: "twitter"))
  end
end
