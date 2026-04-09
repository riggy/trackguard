FactoryBot.define do
  factory :visitor, class: "Trackguard::Visitor" do
    sequence(:ip) { |n| "192.168.#{n / 254 + 1}.#{n % 254 + 1}" }
    user_agent    { "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36" }
    first_seen_at { Time.current }
    last_seen_at  { Time.current }

    trait :flagged do
      flagged_at  { Time.current }
      flag_reason { "suspicious activity" }
      flagged_by  { "system" }
    end
  end
end
