require "rails_helper"
require "generators/trackguard/upgrade_generator"

RSpec.describe Trackguard::UpgradeGenerator do
  let(:destination) { Dir.mktmpdir }

  before { FileUtils.mkdir_p(File.join(destination, "db", "migrate")) }
  after  { FileUtils.rm_rf(destination) }

  def run_generator
    original = $stdout
    $stdout = StringIO.new
    Trackguard::UpgradeGenerator.start([], destination_root: destination)
  ensure
    $stdout = original
  end

  def generated_migration
    Dir[File.join(destination, "db", "migrate", "*.rb")].find { |f| f.include?("add_trackguard_visits") }
  end

  it "creates exactly three migration files" do
    run_generator
    expect(Dir[File.join(destination, "db", "migrate", "*.rb")].length).to eq(3)
  end

  it "gives the migration a valid timestamp-based filename" do
    run_generator
    expect(File.basename(generated_migration)).to match(/\A\d{14}_add_trackguard_visits\.rb\z/)
  end

  it "generates an AddTrackguardVisits migration class" do
    run_generator
    expect(File.read(generated_migration)).to include("class AddTrackguardVisits < ActiveRecord::Migration")
  end

  it "renames the page_views table to visits" do
    run_generator
    content = File.read(generated_migration)
    expect(content).to include("rename_table :trackguard_page_views, :trackguard_visits")
  end

  it "adds the STI type column" do
    run_generator
    expect(File.read(generated_migration)).to include(":type")
  end

  it "adds block_reason and http_method columns" do
    run_generator
    content = File.read(generated_migration)
    expect(content).to include(":block_reason")
    expect(content).to include(":http_method")
  end

  context "add_visitor_name migration" do
    def generated_migrations
      Dir[File.join(destination, "db", "migrate", "*.rb")]
    end

    def visitor_name_migration
      generated_migrations.find { |f| f.include?("add_visitor_name") }
    end

    before { run_generator }

    it "gives the migration a valid timestamp-based filename" do
      expect(File.basename(visitor_name_migration)).to match(/\A\d{14}_add_visitor_name\.rb\z/)
    end

    it "generates an AddVisitorName migration class" do
      expect(File.read(visitor_name_migration)).to include("class AddVisitorName < ActiveRecord::Migration")
    end

    it "adds the name column to trackguard_visitors" do
      expect(File.read(visitor_name_migration)).to include(":name")
    end
  end

  context "add_trackguard_blocked_paths migration" do
    def blocked_paths_migration
      Dir[File.join(destination, "db", "migrate", "*.rb")].find { |f| f.include?("add_trackguard_blocked_paths") }
    end

    before { run_generator }

    it "gives the migration a valid timestamp-based filename" do
      expect(File.basename(blocked_paths_migration)).to match(/\A\d{14}_add_trackguard_blocked_paths\.rb\z/)
    end

    it "generates an AddTrackguardBlockedPaths migration class" do
      expect(File.read(blocked_paths_migration)).to include("class AddTrackguardBlockedPaths < ActiveRecord::Migration")
    end

    it "creates the blocked_paths table with a unique pattern index" do
      content = File.read(blocked_paths_migration)
      expect(content).to include("create_table :trackguard_blocked_paths")
      expect(content).to include("add_index :trackguard_blocked_paths, :pattern, unique: true")
    end
  end
end
