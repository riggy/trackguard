FactoryBot.define do
  factory :blocked_path, class: "Trackguard::BlockedPath" do
    sequence(:pattern) { |n| "/probe-#{n}" }
  end
end
