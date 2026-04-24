require "rails_helper"

RSpec.describe Trackguard::DetectSuspiciousVisitorsJob, type: :job do
  before do
    Trackguard::PageView.delete_all
    Trackguard::Visitor.delete_all
  end

  def run_job
    described_class.perform_now
  end

  # --- hard flag ---

  it "flags visitor with 50+ page views in 24h (hard flag)" do
    v = create(:visitor)
    create_list(:page_view, 50, visitor: v)
    run_job
    v.reload
    expect(v.flagged_at).not_to be_nil
    expect(v.flag_reason).to include("hard flag threshold")
  end

  it "flags visitor with exactly 50 views (hard flag boundary)" do
    v = create(:visitor)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  # --- scoring: flagged cases ---

  it "flags visitor with 12 views + no session + no referer (score 9)" do
    v = create(:visitor)
    create_list(:page_view, 12, visitor: v, session_id: nil, referer: nil)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  it "flags visitor with 10 views + no session + no referer (score 7)" do
    v = create(:visitor)
    create_list(:page_view, 10, visitor: v, session_id: nil, referer: nil)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  it "flags visitor with 20 views all to root + no session (score 7)" do
    v = create(:visitor)
    create_list(:page_view, 20, visitor: v, path: "/", session_id: nil)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  it "flags visitor with 20 views to single non-root path + no session (score 7)" do
    v = create(:visitor)
    create_list(:page_view, 20, visitor: v, path: "/about", session_id: nil)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  # --- scoring: NOT flagged cases ---

  it "does not flag visitor with 8 views all having session (score 2)" do
    v = create(:visitor)
    create_list(:page_view, 8, visitor: v, session_id: "hashed_session_value")
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "does not flag visitor with no session alone, 3 views (score 2)" do
    v = create(:visitor)
    # Use distinct paths so single_path does not also trigger
    %w[/ /blog /about].each do |path|
      create(:page_view, visitor: v, path: path, session_id: nil, referer: "https://google.com", created_at: 1.hour.ago)
    end
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "does not flag visitor with no referer alone (score 2)" do
    v = create(:visitor)
    create_list(:page_view, 3, visitor: v, session_id: "abc123", referer: nil)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  # --- boundary: 80% threshold is not > 80% ---

  it "does not trigger no-session signal at exactly 80% blank" do
    v = create(:visitor)
    # 8 blank + 2 with session = exactly 80%, which is NOT > 0.8 (the threshold)
    # Use distinct paths and present referers so no other signals trigger.
    # Score: high_volume (10 views = +4) only → 4, below threshold 5.
    8.times { |i| create(:page_view, visitor: v, path: "/page-#{i}",  session_id: nil,      referer: "https://google.com", created_at: 1.hour.ago) }
    2.times { |i| create(:page_view, visitor: v, path: "/other-#{i}", session_id: "hashed", referer: "https://google.com", created_at: 1.hour.ago) }
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  # --- already-flagged visitors are skipped ---

  it "does not modify already-flagged visitor" do
    original_time   = 1.day.ago
    original_reason = "original reason"
    v = create(:visitor, flagged_at: original_time, flag_reason: original_reason)
    create_list(:page_view, 25, visitor: v, session_id: nil, referer: nil)
    run_job
    v.reload
    expect(v.flagged_at).to be_within(1.second).of(original_time)
    expect(v.flag_reason).to eq(original_reason)
  end

  # --- views outside 24h window are ignored ---

  it "does not flag visitor whose views are all older than 24h" do
    v = create(:visitor)
    create_list(:page_view, 25, visitor: v, session_id: nil, referer: nil, created_at: 25.hours.ago)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  # --- flag_reason content ---

  it "flag_reason describes triggered signals" do
    v = create(:visitor)
    create_list(:page_view, 10, visitor: v, path: "/about", session_id: nil, referer: nil)
    run_job
    v.reload
    expect(v.flagged_at).not_to be_nil
    expect(v.flag_reason).to include("no session")
    expect(v.flag_reason).to include("no referer")
  end

  # --- whitelist ---

  it "skips flagging a visitor with an active whitelist entry" do
    v = create(:visitor)
    create(:whitelisted_ip, ip: v.ip, visitor: v)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "flags a visitor whose whitelist entry has expired" do
    v = create(:visitor)
    create(:whitelisted_ip, :expired, ip: v.ip, visitor: v)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  # --- cross-visitor trace_id sharing ---

  context "cross-visitor trace_id sharing" do
    let(:shared_trace_id) { SecureRandom.hex(8) }
    let(:v1) { create(:visitor) }
    let(:v2) { create(:visitor) }
    let!(:pv1) { create(:page_view, visitor: v1, trace_id: shared_trace_id) }
    let!(:pv2) { create(:page_view, visitor: v2, trace_id: shared_trace_id) }

    it "flags both visitors" do
      run_job
      expect(v1.reload.flagged_at).not_to be_nil
      expect(v2.reload.flagged_at).not_to be_nil
    end

    it "sets a descriptive flag_reason" do
      run_job
      v1.reload
      expect(v1.flag_reason).to include("trace_id shared across multiple visitors")
      expect(v1.flagged_by).to eq("claw:auto")
    end

    context "when v1 is already flagged" do
      let(:v1) { create(:visitor, flagged_at: 1.hour.ago, flag_reason: "prior reason", flagged_by: "User") }

      it "does not overwrite the existing flag_reason" do
        run_job
        expect(v1.reload.flag_reason).to eq("prior reason")
      end
    end

    context "when v1 is whitelisted" do
      let!(:whitelist) { create(:whitelisted_ip, ip: v1.ip, visitor: v1) }

      it "skips v1 but still flags the partner" do
        run_job
        expect(v1.reload.flagged_at).to be_nil
        expect(v2.reload.flagged_at).not_to be_nil
      end
    end

    context "when trace_ids are unique per visitor" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: SecureRandom.hex(8)) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: SecureRandom.hex(8)) }

      it "does not flag either visitor" do
        run_job
        expect(v1.reload.flagged_at).to be_nil
        expect(v2.reload.flagged_at).to be_nil
      end
    end

    context "when page views are older than 24h" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: shared_trace_id, created_at: 25.hours.ago) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: shared_trace_id, created_at: 25.hours.ago) }

      it "ignores the shared trace_id" do
        run_job
        expect(v1.reload.flagged_at).to be_nil
        expect(v2.reload.flagged_at).to be_nil
      end
    end

    context "when trace_ids are nil" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: nil) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: nil) }

      it "does not flag either visitor" do
        run_job
        expect(v1.reload.flagged_at).to be_nil
        expect(v2.reload.flagged_at).to be_nil
      end
    end

    context "when three visitors share a trace_id" do
      let(:v3) { create(:visitor) }
      let!(:pv3) { create(:page_view, visitor: v3, trace_id: shared_trace_id) }

      it "flags all three" do
        run_job
        [ v1, v2, v3 ].each { |v| expect(v.reload.flagged_at).not_to be_nil }
      end
    end
  end

  # --- UA: blank or minimal ---

  it "flags visitor with blank user_agent" do
    v = create(:visitor, user_agent: "")
    create(:page_view, visitor: v)
    run_job
    v.reload
    expect(v.flagged_at).not_to be_nil
    expect(v.flag_reason).to eq("blank or minimal user-agent")
  end

  it "flags visitor with nil user_agent" do
    v = create(:visitor, user_agent: nil)
    create(:page_view, visitor: v)
    run_job
    expect(v.reload.flagged_at).not_to be_nil
  end

  it "flags visitor with user_agent shorter than 10 chars" do
    v = create(:visitor, user_agent: "curl")
    create(:page_view, visitor: v)
    run_job
    v.reload
    expect(v.flagged_at).not_to be_nil
    expect(v.flag_reason).to eq("blank or minimal user-agent")
  end

  it "does not flag visitor with a normal browser user_agent" do
    v = create(:visitor, user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    create(:page_view, visitor: v)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  # --- structural: no session, no referrer, single root hit ---

  it "does not flag visitor with fewer than MIN_VIEWS root-only hits (below threshold)" do
    v = create(:visitor)
    create_list(:page_view, 2, visitor: v, path: "/", session_id: nil, referer: nil)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "flags visitor with MIN_VIEWS+ root-only views all missing session and referrer" do
    v = create(:visitor)
    create_list(:page_view, 3, visitor: v, path: "/", session_id: nil, referer: nil)
    run_job
    v.reload
    expect(v.flagged_at).not_to be_nil
    expect(v.flag_reason).to eq("no session, no referrer, single root hit")
  end

  it "does not flag visitor who hits / with a session present" do
    v = create(:visitor)
    create(:page_view, visitor: v, path: "/", session_id: "abc123", referer: nil)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "does not flag visitor who visits / and another path (mixed)" do
    v = create(:visitor)
    create(:page_view, visitor: v, path: "/", session_id: nil, referer: nil)
    create(:page_view, visitor: v, path: "/about", session_id: "abc123", referer: nil)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  # --- no-op when nothing to process ---

  it "completes without error when no unflagged visitors exist" do
    expect { run_job }.not_to raise_error
  end

  it "completes without error when no page views in last 24h" do
    create(:visitor)
    expect { run_job }.not_to raise_error
  end
end
