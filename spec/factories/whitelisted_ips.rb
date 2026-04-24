FactoryBot.define do
  factory :whitelisted_ip, class: "Trackguard::WhitelistedIp" do
    sequence(:ip) { |n| "10.0.#{n / 254 + 1}.#{n % 254 + 1}" }
    expires_at { 30.days.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
