require "rails_helper"
require "generators/trackguard/install_generator"
require "generators/trackguard/upgrade_generator"

RSpec.describe Trackguard::UpgradeGenerator do
  let(:destination) { Dir.mktmpdir }

  before { FileUtils.mkdir_p(File.join(destination, "db", "migrate")) }
  after  { FileUtils.rm_rf(destination) }

  def run_generator(klass = described_class)
    original = $stdout
    $stdout = StringIO.new
    klass.start([], destination_root: destination)
  ensure
    $stdout = original
  end

  def migrations
    Dir[File.join(destination, "db", "migrate", "*.rb")]
  end

  def migration_named(name)
    migrations.find { |f| f.include?(name) }
  end

  it "creates exactly five migration files" do
    run_generator
    expect(migrations.length).to eq(5)
  end

  it "gives each migration a valid timestamp-based filename" do
    run_generator
    migrations.each do |f|
      expect(File.basename(f)).to match(/\A\d{14}_\w+\.rb\z/)
    end
  end

  it "generates the same migrations as the install generator" do
    run_generator
    names = migrations.map { |f| File.basename(f).sub(/\A\d{14}_/, "") }.sort
    expected = %w[
      create_trackguard_blocked_paths.rb
      create_trackguard_blocked_user_agents.rb
      create_trackguard_visitors.rb
      create_trackguard_visits.rb
      create_trackguard_whitelisted_ips.rb
    ]
    expect(names).to eq(expected)
  end

  it "skips migrations that already exist from a prior install" do
    run_generator(Trackguard::InstallGenerator)
    run_generator
    expect(migrations.length).to eq(5)
  end

  describe "create_trackguard_visitors migration" do
    before { run_generator }

    it "creates the visitors table" do
      content = File.read(migration_named("create_trackguard_visitors"))
      expect(content).to include("class CreateTrackguardVisitors < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_visitors")
    end
  end

  describe "create_trackguard_visits migration" do
    before { run_generator }

    it "creates the visits table directly (not via rename)" do
      content = File.read(migration_named("create_trackguard_visits"))
      expect(content).to include("class CreateTrackguardVisits < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_visits")
      expect(content).not_to include("rename_table")
    end
  end

  describe "create_trackguard_blocked_paths migration" do
    before { run_generator }

    it "creates the blocked_paths table with a unique pattern index" do
      content = File.read(migration_named("create_trackguard_blocked_paths"))
      expect(content).to include("class CreateTrackguardBlockedPaths < ActiveRecord::Migration")
      expect(content).to include("create_table :trackguard_blocked_paths")
      expect(content).to include("add_index :trackguard_blocked_paths, :pattern, unique: true")
    end
  end

  it "prints next steps including the seed_blocked_paths task" do
    buffer = StringIO.new
    original = $stdout
    $stdout = buffer
    described_class.start([], destination_root: destination)
    expect(buffer.string).to include("trackguard:seed_blocked_paths")
  ensure
    $stdout = original
  end
end
