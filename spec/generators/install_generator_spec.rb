require "rails_helper"
require "generators/trackguard/install_generator"

RSpec.describe Trackguard::InstallGenerator do
  let(:destination) { Dir.mktmpdir }

  before { FileUtils.mkdir_p(File.join(destination, "db", "migrate")) }
  after  { FileUtils.rm_rf(destination) }

  def run_generator
    original = $stdout
    $stdout = StringIO.new
    Trackguard::InstallGenerator.start([], destination_root: destination)
  ensure
    $stdout = original
  end

  def run_generator_capturing_output
    buffer = StringIO.new
    original = $stdout
    $stdout = buffer
    Trackguard::InstallGenerator.start([], destination_root: destination)
    buffer.string
  ensure
    $stdout = original
  end

  def migrations
    Dir[File.join(destination, "db", "migrate", "*.rb")]
  end

  def migration_named(name)
    migrations.find { |f| f.include?(name) }
  end

  it "creates exactly six migration files" do
    run_generator
    expect(migrations.length).to eq(6)
  end

  it "is idempotent — re-running skips already-existing migrations" do
    run_generator
    run_generator
    expect(migrations.length).to eq(6)
  end

  it "gives each migration a valid timestamp-based filename" do
    run_generator
    migrations.each do |f|
      expect(File.basename(f)).to match(/\A\d{14}_\w+\.rb\z/)
    end
  end

  describe "create_trackguard_visitors migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("create_trackguard_visitors")).not_to be_nil
    end

    it "creates the visitors table with the expected columns" do
      content = File.read(migration_named("create_trackguard_visitors"))
      expect(content).to include("class CreateTrackguardVisitors < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_visitors")
      expect(content).to include(":first_seen_at")
      expect(content).to include(":last_seen_at")
      expect(content).to include(":flagged_at")
      expect(content).to include(":flagged_by")
      expect(content).to include(":name")
    end

    it "adds a unique index on ip" do
      expect(File.read(migration_named("create_trackguard_visitors"))).to include(
        "add_index :trackguard_visitors, :ip, unique: true"
      )
    end
  end

  describe "create_trackguard_visits migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("create_trackguard_visits")).not_to be_nil
    end

    it "creates the visits table with the expected columns" do
      content = File.read(migration_named("create_trackguard_visits"))
      expect(content).to include("class CreateTrackguardVisits < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_visits")
      expect(content).to include(":type")
      expect(content).to include(":path")
      expect(content).to include(":session_id")
      expect(content).to include(":trace_id")
      expect(content).to include(":source")
      expect(content).to include(":block_reason")
      expect(content).to include(":http_method")
      expect(content).to include(":tracking_layer")
      expect(content).to include(":visitor")
    end
  end

  describe "add_tracking_layer_to_trackguard_visits migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("add_tracking_layer_to_trackguard_visits")).not_to be_nil
    end

    it "adds a nullable tracking_layer string column" do
      content = File.read(migration_named("add_tracking_layer_to_trackguard_visits"))
      expect(content).to include("class AddTrackingLayerToTrackguardVisits < ActiveRecord::Migration")
      expect(content).to include("add_column :trackguard_visits, :tracking_layer, :string")
    end
  end

  describe "create_trackguard_whitelisted_ips migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("create_trackguard_whitelisted_ips")).not_to be_nil
    end

    it "creates the whitelisted_ips table" do
      content = File.read(migration_named("create_trackguard_whitelisted_ips"))
      expect(content).to include("class CreateTrackguardWhitelistedIps < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_whitelisted_ips")
      expect(content).to include(":expires_at")
    end
  end

  describe "create_trackguard_blocked_user_agents migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("create_trackguard_blocked_user_agents")).not_to be_nil
    end

    it "creates the blocked_user_agents table with a unique pattern index" do
      content = File.read(migration_named("create_trackguard_blocked_user_agents"))
      expect(content).to include("class CreateTrackguardBlockedUserAgents < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_blocked_user_agents")
      expect(content).to include("add_index :trackguard_blocked_user_agents, :pattern, unique: true")
    end
  end

  describe "create_trackguard_blocked_paths migration" do
    before { run_generator }

    it "is generated" do
      expect(migration_named("create_trackguard_blocked_paths")).not_to be_nil
    end

    it "creates the blocked_paths table with a unique pattern index" do
      content = File.read(migration_named("create_trackguard_blocked_paths"))
      expect(content).to include("class CreateTrackguardBlockedPaths < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_blocked_paths")
      expect(content).to include("add_index :trackguard_blocked_paths, :pattern, unique: true")
    end
  end

  it "prints next steps including both seed tasks" do
    output = run_generator_capturing_output
    expect(output).to include("trackguard:seed_blocked_user_agents")
    expect(output).to include("trackguard:seed_blocked_paths")
  end
end
