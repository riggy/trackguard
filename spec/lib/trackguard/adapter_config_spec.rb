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

RSpec.describe "Trackguard.tracking_enabled?" do
  after { Trackguard.instance_variable_set(:@disable_on_development, nil) }

  context "when not in development" do
    it "returns true regardless of disable_on_development" do
      Trackguard.configure { |c| c.disable_on_development = true }
      expect(Trackguard.tracking_enabled?).to be true
    end
  end

  context "when in development" do
    before { allow(Rails.env).to receive(:development?).and_return(true) }

    it "returns false by default (disable_on_development defaults to true)" do
      expect(Trackguard.tracking_enabled?).to be false
    end

    it "returns false when disable_on_development is explicitly true" do
      Trackguard.configure { |c| c.disable_on_development = true }
      expect(Trackguard.tracking_enabled?).to be false
    end

    it "returns true when disable_on_development is false" do
      Trackguard.configure { |c| c.disable_on_development = false }
      expect(Trackguard.tracking_enabled?).to be true
    end
  end
end
