require "rails_helper"

RSpec.describe "Admin visitor flag actions", type: :request do
  let!(:visitor) { create(:visitor) }

  describe "PATCH /admin/visitors/:id/flag" do
    it "flags the visitor" do
      patch "/admin/visitors/#{visitor.id}/flag", params: { flag_reason: "suspicious" }
      expect(visitor.reload.flagged_at).not_to be_nil
    end

    it "sets flag_reason from params" do
      patch "/admin/visitors/#{visitor.id}/flag", params: { flag_reason: "scraper" }
      expect(visitor.reload.flag_reason).to eq("scraper")
    end

    it "sets flagged_by to the first FLAGGED_BY value" do
      patch "/admin/visitors/#{visitor.id}/flag", params: {}
      expect(visitor.reload.flagged_by).to eq(Trackguard::Visitor::FLAGGED_BY.first)
    end

    it "accepts a blank flag_reason" do
      patch "/admin/visitors/#{visitor.id}/flag", params: { flag_reason: "" }
      expect(visitor.reload.flag_reason).to be_nil
    end

    it "redirects after flagging" do
      patch "/admin/visitors/#{visitor.id}/flag", params: {}
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /admin/visitors/:id/unflag" do
    let!(:visitor) { create(:visitor, :flagged) }

    it "clears flagged_at" do
      patch "/admin/visitors/#{visitor.id}/unflag"
      expect(visitor.reload.flagged_at).to be_nil
    end

    it "clears flag_reason and flagged_by" do
      patch "/admin/visitors/#{visitor.id}/unflag"
      v = visitor.reload
      expect(v.flag_reason).to be_nil
      expect(v.flagged_by).to be_nil
    end

    it "redirects after unflagging" do
      patch "/admin/visitors/#{visitor.id}/unflag"
      expect(response).to have_http_status(:redirect)
    end
  end
end