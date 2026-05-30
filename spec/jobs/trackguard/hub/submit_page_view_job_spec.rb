# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::Hub::SubmitPageViewJob, type: :job do
  let(:hub_url)        { "https://hub.example.com" }
  let(:page_views_url) { "#{hub_url}/api/backend/page_views" }

  let(:base_params) do
    {
      path: "/blog",
      ip: "1.2.3.4",
      user_agent: "Mozilla/5.0",
      referer: "https://example.com",
      session_id: "sess-abc",
      trace_id: "trace-xyz",
      source: "organic",
      tracking_layer: "js",
      http_method: "GET"
    }
  end

  before do
    Trackguard.hub_url        = hub_url
    Trackguard.hub_api_key    = "test-api-key"
    Trackguard.hub_secret_key = "test-secret"
  end

  after do
    Trackguard.hub_url        = nil
    Trackguard.hub_api_key    = nil
    Trackguard.hub_secret_key = nil
  end

  def perform(**overrides)
    described_class.perform_now(**base_params, **overrides)
  end

  def stub_hub(status: 201)
    stub_request(:post, page_views_url)
      .with(headers: {
              "X-Api-Key" => "test-api-key",
              "Authorization" => "Bearer test-secret",
              "Content-Type" => "application/json"
            })
      .to_return(status: status, body: "", headers: {})
  end

  describe "#perform" do
    it "POSTs to the correct URL with correct auth headers" do
      request = stub_hub
      perform
      expect(request).to have_been_made.once
    end

    it "sends the correct JSON body" do
      request = stub_request(:post, page_views_url)
                .with(
                  headers: { "Content-Type" => "application/json" },
                  body: {
                    page_view: {
                      path: "/blog",
                      referer: "https://example.com",
                      session_id: "sess-abc",
                      trace_id: "trace-xyz",
                      source: "organic",
                      http_method: "GET",
                      ip: "1.2.3.4",
                      user_agent: "Mozilla/5.0"
                    }
                  }
                )
                .to_return(status: 201, body: "", headers: {})
      perform
      expect(request).to have_been_made.once
    end

    context "when the hub returns a non-2xx response" do
      it "does not raise" do
        stub_hub(status: 401)
        expect { perform }.not_to raise_error
      end

      it "logs a warning" do
        stub_hub(status: 500)
        expect(Rails.logger).to receive(:warn).with(/SubmitPageViewJob.*500/)
        perform
      end
    end

    context "when the hub is unreachable" do
      before { stub_request(:post, page_views_url).to_raise(Errno::ECONNREFUSED) }

      it "does not raise" do
        expect { perform }.not_to raise_error
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/SubmitPageViewJob.*Failed/)
        perform
      end
    end
  end
end
