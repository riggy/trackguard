# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trackguard.adapter" do
  after { Trackguard.instance_variable_set(:@adapter, nil) }

  it "defaults to a Local adapter instance" do
    expect(Trackguard.adapter).to be_a(Trackguard::Adapters::Local)
  end

  it "resolves a :local symbol to a Local instance" do
    Trackguard.configure { |c| c.adapter = :local }
    expect(Trackguard.adapter).to be_a(Trackguard::Adapters::Local)
  end

  it "instantiates a class reference" do
    Trackguard.configure { |c| c.adapter = Trackguard::Adapters::Local }
    expect(Trackguard.adapter).to be_a(Trackguard::Adapters::Local)
  end

  it "stores a pre-built instance as-is" do
    instance = Trackguard::Adapters::Local.new
    Trackguard.configure { |c| c.adapter = instance }
    expect(Trackguard.adapter).to be(instance)
  end
end
