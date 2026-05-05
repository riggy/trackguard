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
    Dir[File.join(destination, "db", "migrate", "*.rb")].first
  end

  it "creates exactly one migration file" do
    run_generator
    expect(Dir[File.join(destination, "db", "migrate", "*.rb")].length).to eq(1)
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
end
