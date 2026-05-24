require "rails_helper"

RSpec.describe Trackguard::DetectSuspiciousVisitorsJob, type: :job do
  before do
    Trackguard::PageView.delete_all
    Trackguard::Visitor.delete_all
  end

  def run_job
    described_class.perform_now
  end

  def expect_blocked(visitor)
    visitor.reload
    expect(visitor).to be_blocked
    expect(visitor.flagged_at).not_to be_nil
  end

  def expect_suspicious(visitor)
    visitor.reload
    expect(visitor).to be_suspicious
    expect(visitor.suspicious_since_at).not_to be_nil
    expect(visitor.flagged_at).to be_nil
  end

  def expect_normal(visitor)
    visitor.reload
    expect(visitor).to be_normal
    expect(visitor.flagged_at).to be_nil
    expect(visitor.suspicious_since_at).to be_nil
  end

  # --- hard flag ---

  it "blocks visitor with 50+ page views in 24h (hard flag)" do
    v = create(:visitor)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to include("hard flag threshold")
  end

  it "blocks visitor with exactly 50 views (hard flag boundary)" do
    v = create(:visitor)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect_blocked(v)
  end

  # --- scoring: blocked cases ---

  it "blocks visitor with 12 views + no session + no referer (single-path rule)" do
    v = create(:visitor)
    create_list(:page_view, 12, visitor: v, session_id: nil, referer: nil)
    run_job
    expect_blocked(v)
  end

  it "blocks visitor with 10 views + no session + no referer (single-path rule)" do
    v = create(:visitor)
    create_list(:page_view, 10, visitor: v, session_id: nil, referer: nil)
    run_job
    expect_blocked(v)
  end

  it "blocks visitor with 20 views all to root + no session (score 7)" do
    v = create(:visitor)
    create_list(:page_view, 20, visitor: v, path: "/", session_id: nil)
    run_job
    expect_blocked(v)
  end

  it "blocks visitor with 20 views to single non-root path + no session (score 7)" do
    v = create(:visitor)
    create_list(:page_view, 20, visitor: v, path: "/about", session_id: nil)
    run_job
    expect_blocked(v)
  end

  # --- scoring: NOT flagged cases ---

  it "does not flag visitor with 8 views all having session (score 2)" do
    v = create(:visitor)
    create_list(:page_view, 8, visitor: v, session_id: "hashed_session_value")
    run_job
    expect_normal(v)
  end

  it "does not flag visitor with no session alone, 3 views (score 2)" do
    v = create(:visitor)
    %w[/ /blog /about].each do |path|
      create(:page_view, visitor: v, path: path, session_id: nil, referer: "https://google.com", created_at: 1.hour.ago)
    end
    run_job
    expect_normal(v)
  end

  it "does not flag visitor with no referer alone (score 0)" do
    v = create(:visitor)
    create_list(:page_view, 3, visitor: v, session_id: "abc123", referer: nil)
    run_job
    expect_normal(v)
  end

  it "blocks visitor with medium volume and majority sessionless views (score 5)" do
    v = create(:visitor)
    9.times { |i| create(:page_view, visitor: v, path: "/p-#{i}", session_id: nil) }
    create(:page_view, visitor: v, path: "/p-9", session_id: "abc")
    run_job
    expect_blocked(v)
  end

  # --- boundary: 80% threshold is not > 80% ---

  it "does not trigger no-session signal at exactly 80% blank" do
    v = create(:visitor)
    8.times { |i| create(:page_view, visitor: v, path: "/page-#{i}",  session_id: nil,      referer: "https://google.com", created_at: 1.hour.ago) }
    2.times { |i| create(:page_view, visitor: v, path: "/other-#{i}", session_id: "hashed", referer: "https://google.com", created_at: 1.hour.ago) }
    run_job
    expect_normal(v)
  end

  # --- already-blocked visitors are skipped ---

  it "does not modify already-blocked visitor" do
    original_time   = 1.day.ago
    original_reason = "original reason"
    v = create(:visitor, suspicious_state: "blocked", flagged_at: original_time, flag_reason: original_reason)
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
    expect_normal(v)
  end

  # --- flag_reason content ---

  it "flag_reason describes triggered signals" do
    v = create(:visitor)
    5.times { |i| create(:page_view, visitor: v, path: "/page-#{i}",  session_id: nil, referer: nil) }
    5.times { |i| create(:page_view, visitor: v, path: "/other-#{i}", session_id: nil, referer: nil) }
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to include("no session")
  end

  # --- whitelist ---

  it "skips flagging a visitor with an active whitelist entry" do
    v = create(:visitor)
    create(:whitelisted_ip, ip: v.ip, visitor: v)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect(v.reload.flagged_at).to be_nil
  end

  it "blocks a visitor whose whitelist entry has expired" do
    v = create(:visitor)
    create(:whitelisted_ip, :expired, ip: v.ip, visitor: v)
    create_list(:page_view, 50, visitor: v)
    run_job
    expect_blocked(v)
  end

  # --- cross-visitor trace_id sharing ---

  context "cross-visitor trace_id sharing" do
    let(:shared_trace_id) { SecureRandom.hex(8) }
    let(:v1) { create(:visitor) }
    let(:v2) { create(:visitor) }
    let!(:pv1) { create(:page_view, visitor: v1, trace_id: shared_trace_id) }
    let!(:pv2) { create(:page_view, visitor: v2, trace_id: shared_trace_id) }

    it "blocks both visitors" do
      run_job
      expect_blocked(v1)
      expect_blocked(v2)
    end

    it "sets a descriptive flag_reason" do
      run_job
      v1.reload
      expect(v1.flag_reason).to include("trace_id shared across multiple visitors")
      expect(v1.flagged_by).to eq("Recurring Job")
    end

    context "when v1 is already blocked" do
      let(:v1) do
        create(:visitor, suspicious_state: "blocked", flagged_at: 1.hour.ago,
                         flag_reason: "prior reason", flagged_by: "User")
      end

      it "does not overwrite the existing flag_reason" do
        run_job
        expect(v1.reload.flag_reason).to eq("prior reason")
      end
    end

    context "when v1 is whitelisted" do
      let!(:whitelist) { create(:whitelisted_ip, ip: v1.ip, visitor: v1) }

      it "skips v1 but still blocks the partner" do
        run_job
        expect(v1.reload.flagged_at).to be_nil
        expect_blocked(v2)
      end
    end

    context "when trace_ids are unique per visitor" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: SecureRandom.hex(8)) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: SecureRandom.hex(8)) }

      it "does not flag either visitor" do
        run_job
        expect_normal(v1)
        expect_normal(v2)
      end
    end

    context "when page views are older than 24h" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: shared_trace_id, created_at: 25.hours.ago) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: shared_trace_id, created_at: 25.hours.ago) }

      it "ignores the shared trace_id" do
        run_job
        expect_normal(v1)
        expect_normal(v2)
      end
    end

    context "when trace_ids are nil" do
      let!(:pv1) { create(:page_view, visitor: v1, trace_id: nil) }
      let!(:pv2) { create(:page_view, visitor: v2, trace_id: nil) }

      it "does not flag either visitor" do
        run_job
        expect_normal(v1)
        expect_normal(v2)
      end
    end

    context "when three visitors share a trace_id" do
      let(:v3) { create(:visitor) }
      let!(:pv3) { create(:page_view, visitor: v3, trace_id: shared_trace_id) }

      it "blocks all three" do
        run_job
        [ v1, v2, v3 ].each { |v| expect_blocked(v) }
      end
    end
  end

  # --- backend-only detection ---

  context "backend-only detection" do
    it "marks suspicious (not blocked) a visitor with only backend-tracked views" do
      v = create(:visitor)
      create_list(:page_view, 3, visitor: v, tracking_layer: "backend")
      run_job
      expect_suspicious(v)
      expect(v.flag_reason).to be_nil
    end

    it "marks suspicious on a single backend-only view (no MIN_VIEWS guard)" do
      v = create(:visitor)
      create(:page_view, visitor: v, tracking_layer: "backend")
      run_job
      expect_suspicious(v)
    end

    it "escalates to blocked in the same run if another blocking rule also fires" do
      v = create(:visitor, user_agent: "curl")
      create(:page_view, visitor: v, tracking_layer: "backend")
      run_job
      expect_blocked(v)
      expect(v.flag_reason).to eq("blank or minimal user-agent")
    end

    it "does not flag a visitor who has at least one JS view" do
      v = create(:visitor)
      create_list(:page_view, 3, visitor: v, tracking_layer: "backend")
      create(:page_view, visitor: v, tracking_layer: "js")
      run_job
      expect_normal(v)
    end

    it "does not flag a visitor with only JS views" do
      v = create(:visitor)
      create_list(:page_view, 3, visitor: v, tracking_layer: "js")
      run_job
      expect_normal(v)
    end

    it "does not flag a visitor with legacy nil tracking_layer views" do
      v = create(:visitor)
      create_list(:page_view, 3, visitor: v, tracking_layer: nil)
      run_job
      expect_normal(v)
    end
  end

  # --- suspicious visitor escalation and recovery ---

  context "suspicious visitor follow-up" do
    let(:suspicious_since) { 2.hours.ago }

    let(:v) do
      create(:visitor, suspicious_state: "suspicious", suspicious_since_at: suspicious_since)
    end

    it "stays suspicious when no new views have arrived since suspicious_since_at" do
      create(:page_view, visitor: v, tracking_layer: "backend", created_at: 3.hours.ago)
      run_job
      v.reload
      expect(v).to be_suspicious
      expect(v.flagged_at).to be_nil
    end

    it "escalates to blocked when new backend-only views exist (unpaired)" do
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: "new-trace", created_at: 1.hour.ago)
      run_job
      expect_blocked(v)
      expect(v.flag_reason).to include("continued backend-only")
    end

    it "escalates to blocked when backend view has nil trace_id (cannot be paired)" do
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: nil, created_at: 1.hour.ago)
      run_job
      expect_blocked(v)
    end

    it "recovers to normal when paired js+backend views exist (same trace_id)" do
      shared = "paired-trace-id"
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: shared, created_at: 1.hour.ago)
      create(:page_view, visitor: v, tracking_layer: "js",      trace_id: shared, created_at: 1.hour.ago)
      run_job
      expect_normal(v)
    end

    it "clears suspicious_since_at on recovery" do
      shared = "paired-trace-id"
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: shared, created_at: 1.hour.ago)
      create(:page_view, visitor: v, tracking_layer: "js",      trace_id: shared, created_at: 1.hour.ago)
      run_job
      expect(v.reload.suspicious_since_at).to be_nil
    end

    it "does not recover on js-only new views (no paired backend)" do
      create(:page_view, visitor: v, tracking_layer: "js", trace_id: "js-only", created_at: 1.hour.ago)
      run_job
      v.reload
      expect(v).to be_suspicious
    end

    it "escalates when both paired and unpaired backend views exist (unpaired wins)" do
      shared = "paired-trace"
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: shared,  created_at: 1.hour.ago)
      create(:page_view, visitor: v, tracking_layer: "js",      trace_id: shared,  created_at: 1.hour.ago)
      create(:page_view, visitor: v, tracking_layer: "backend", trace_id: "solo",  created_at: 1.hour.ago)
      run_job
      expect_blocked(v)
    end

    it "escalates to blocked via other rules (hard threshold) even when suspicious" do
      create_list(:page_view, 50, visitor: v)
      run_job
      expect_blocked(v)
      expect(v.flag_reason).to include("hard flag threshold")
    end

    it "escalates to blocked via scoring even when suspicious" do
      9.times { |i| create(:page_view, visitor: v, path: "/p-#{i}", session_id: nil) }
      create(:page_view, visitor: v, path: "/p-9", session_id: "abc")
      run_job
      expect_blocked(v)
    end

    it "ignores new views created before suspicious_since_at for recovery/escalation" do
      create(:page_view, visitor: v, tracking_layer: "backend",
                         trace_id: "old-trace", created_at: suspicious_since - 1.minute)
      run_job
      v.reload
      expect(v).to be_suspicious
    end
  end

  # --- probe path detection ---

  context "probe path detection" do
    before { Rails.cache.delete(Trackguard::BlockedPath::CACHE_KEY) }

    it "blocks visitor who hit a blocked path" do
      create(:blocked_path, pattern: "/.env")
      v = create(:visitor)
      create(:page_view, visitor: v, path: "/.env")
      run_job
      expect_blocked(v)
      expect(v.flag_reason).to eq("probe path hit: /.env")
    end

    it "blocks visitor whose view path contains the pattern as a substring" do
      create(:blocked_path, pattern: "/.env")
      v = create(:visitor)
      create(:page_view, visitor: v, path: "/.env.backup")
      run_job
      expect_blocked(v)
    end

    it "does not flag visitor whose views hit no blocked path" do
      create(:blocked_path, pattern: "/.env")
      v = create(:visitor)
      create(:page_view, visitor: v, path: "/posts/hello")
      run_job
      expect_normal(v)
    end

    it "does not flag when no blocked paths are configured" do
      v = create(:visitor)
      create(:page_view, visitor: v, path: "/.env")
      run_job
      expect_normal(v)
    end

    it "fires before the MIN_VIEWS check — blocks on a single probe hit" do
      create(:blocked_path, pattern: "/wp-login.php")
      v = create(:visitor)
      create(:page_view, visitor: v, path: "/wp-login.php")
      run_job
      expect_blocked(v)
    end
  end

  # --- UA: blank or minimal ---

  it "blocks visitor with blank user_agent" do
    v = create(:visitor, user_agent: "")
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("blank or minimal user-agent")
  end

  it "blocks visitor with nil user_agent" do
    v = create(:visitor, user_agent: nil)
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
  end

  it "blocks visitor with user_agent shorter than 10 chars" do
    v = create(:visitor, user_agent: "curl")
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("blank or minimal user-agent")
  end

  it "does not flag visitor with a normal browser user_agent" do
    v = create(:visitor, user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    create(:page_view, visitor: v)
    run_job
    expect_normal(v)
  end

  it "blocks visitor with bare Mozilla/5.0 user_agent" do
    v = create(:visitor, user_agent: "Mozilla/5.0")
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("bare Mozilla/5.0 user-agent")
  end

  it "blocks visitor with quoted user_agent" do
    v = create(:visitor, user_agent: '"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"')
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("malformed user-agent (quoted)")
  end

  it "blocks visitor with concatenated duplicate user_agent" do
    dup_ua = "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36, " \
             "Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
    v = create(:visitor, user_agent: dup_ua)
    create(:page_view, visitor: v)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("malformed user-agent (duplicate)")
  end

  # --- visitor name detection ---

  context "visitor name detection" do
    before { Rails.cache.delete(Trackguard::BlockedUserAgent::CACHE_KEY) }

    it "sets name from a matching BlockedUserAgent pattern when blocked by minimal UA" do
      create(:blocked_user_agent, pattern: "curl")
      v = create(:visitor, user_agent: "curl")
      create(:page_view, visitor: v)
      run_job
      expect(v.reload.name).to eq("curl")
    end

    it "leaves name nil when blocked by blank UA and no pattern matches" do
      v = create(:visitor, user_agent: "")
      create(:page_view, visitor: v)
      run_job
      expect(v.reload.name).to be_nil
    end

    it "sets name when a score-blocked visitor UA matches a BlockedUserAgent pattern" do
      create(:blocked_user_agent, pattern: "HeadlessChrome")
      v = create(:visitor, user_agent: "Mozilla/5.0 HeadlessChrome/120")
      create_list(:page_view, 10, visitor: v, session_id: nil, referer: nil)
      run_job
      expect(v.reload.name).to eq("HeadlessChrome")
    end

    it "leaves name nil when no BlockedUserAgent pattern matches" do
      v = create(:visitor, user_agent: "Mozilla/5.0 (Windows NT 10.0)")
      create_list(:page_view, 10, visitor: v, session_id: nil, referer: nil)
      run_job
      expect(v.reload.name).to be_nil
    end

    it "sets name when hard-threshold visitor UA matches a pattern" do
      create(:blocked_user_agent, pattern: "Scrapy")
      v = create(:visitor, user_agent: "Scrapy/2.5.1 (+https://scrapy.org)")
      create_list(:page_view, 50, visitor: v)
      run_job
      expect(v.reload.name).to eq("Scrapy")
    end

    it "sets name when marked suspicious by backend-only and UA matches a pattern" do
      create(:blocked_user_agent, pattern: "MyBot")
      v = create(:visitor, user_agent: "MyBot/1.0")
      create(:page_view, visitor: v, tracking_layer: "backend")
      run_job
      expect(v.reload.name).to eq("MyBot")
    end

    it "sets name for cross-visitor trace_id sharing when UA matches a pattern" do
      create(:blocked_user_agent, pattern: "axios")
      shared = SecureRandom.hex(8)
      v1 = create(:visitor, user_agent: "axios/0.21.1")
      v2 = create(:visitor, user_agent: "axios/0.21.1")
      create(:page_view, visitor: v1, trace_id: shared)
      create(:page_view, visitor: v2, trace_id: shared)
      run_job
      expect(v1.reload.name).to eq("axios")
      expect(v2.reload.name).to eq("axios")
    end
  end

  # --- structural: no session, no referrer, single path hit ---

  it "does not flag visitor with fewer than MIN_VIEWS single-path hits (below threshold)" do
    v = create(:visitor)
    create_list(:page_view, 2, visitor: v, path: "/", session_id: nil, referer: nil)
    run_job
    expect_normal(v)
  end

  it "blocks visitor with MIN_VIEWS+ hits to / all missing session and referrer" do
    v = create(:visitor)
    create_list(:page_view, 3, visitor: v, path: "/", session_id: nil, referer: nil)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("no session, no referrer, single path hit")
  end

  it "blocks visitor with MIN_VIEWS+ hits to a non-root path all missing session and referrer" do
    v = create(:visitor)
    create_list(:page_view, 3, visitor: v, path: "/about", session_id: nil, referer: nil)
    run_job
    expect_blocked(v)
    expect(v.flag_reason).to eq("no session, no referrer, single path hit")
  end

  it "does not flag visitor who hits a single path with a session present" do
    v = create(:visitor)
    create(:page_view, visitor: v, path: "/", session_id: "abc123", referer: nil)
    run_job
    expect_normal(v)
  end

  it "does not flag visitor who visits two different paths without session or referrer" do
    v = create(:visitor)
    create_list(:page_view, 2, visitor: v, path: "/",      session_id: nil, referer: nil)
    create_list(:page_view, 2, visitor: v, path: "/about", session_id: nil, referer: nil)
    run_job
    expect_normal(v)
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
