FactoryBot.define do
  factory :blocked_user_agent, class: "Trackguard::BlockedUserAgent" do
    sequence(:pattern) { |n| "badbot-#{n}" }
  end
end
