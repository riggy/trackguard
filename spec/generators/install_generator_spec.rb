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

  def generated_migration
    Dir[File.join(destination, "db", "migrate", "*.rb")].first
  end

  it "creates exactly one migration file" do
    run_generator
    expect(Dir[File.join(destination, "db", "migrate", "*.rb")].length).to eq(1)
  end

  it "gives the migration a valid timestamp-based filename" do
    run_generator
    expect(File.basename(generated_migration)).to match(/\A\d{14}_create_trackguard_tables\.rb\z/)
  end

  it "generates a CreateTrackguardTables migration class" do
    run_generator
    expect(File.read(generated_migration)).to include("class CreateTrackguardTables < ActiveRecord::Migration")
  end

  it "creates the visitors table with the expected columns" do
    run_generator
    content = File.read(generated_migration)
    expect(content).to include("create_table :trackguard_visitors")
    expect(content).to include(":first_seen_at")
    expect(content).to include(":last_seen_at")
    expect(content).to include(":flagged_at")
    expect(content).to include(":flagged_by")
  end

  it "adds a unique index on visitors.ip" do
    run_generator
    expect(File.read(generated_migration)).to include("add_index :trackguard_visitors, :ip, unique: true")
  end

  it "creates the visits table with the expected columns" do
    run_generator
    content = File.read(generated_migration)
    expect(content).to include("create_table :trackguard_visits")
    expect(content).to include(":type")
    expect(content).to include(":path")
    expect(content).to include(":session_id")
    expect(content).to include(":trace_id")
    expect(content).to include(":source")
    expect(content).to include(":block_reason")
    expect(content).to include(":http_method")
    expect(content).to include(":visitor")
  end

  it "creates the blocked_user_agents table" do
    run_generator
    content = File.read(generated_migration)
    expect(content).to include("create_table :trackguard_blocked_user_agents")
    expect(content).to include("add_index :trackguard_blocked_user_agents, :pattern, unique: true")
  end

  it "prints next steps including the seed task" do
    output = run_generator_capturing_output
    expect(output).to include("trackguard:seed_blocked_user_agents")
  end
end
