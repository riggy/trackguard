# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trackguard::ApplicationHelper, type: :helper do
  describe "#trackguard_header_tags" do
    context "when tracking is enabled" do
      before { allow(Trackguard).to receive(:tracking_enabled?).and_return(true) }

      it "includes the trace-id meta tag" do
        assign(:trace_id, "abc-123")
        expect(helper.trackguard_header_tags).to include("trace-id")
      end
    end

    context "when tracking is disabled" do
      before { allow(Trackguard).to receive(:tracking_enabled?).and_return(false) }

      it "returns an empty string" do
        expect(helper.trackguard_header_tags).to eq ""
      end

      it "returns an html_safe string" do
        expect(helper.trackguard_header_tags).to be_html_safe
      end
    end
  end
end
