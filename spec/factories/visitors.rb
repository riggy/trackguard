FactoryBot.define do
  factory :visitor, class: "Trackguard::Visitor" do
    sequence(:ip) { |n| "192.168.#{(n / 254) + 1}.#{(n % 254) + 1}" }
    user_agent    do
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    end
    first_seen_at { Time.current }
    last_seen_at  { Time.current }

    trait :flagged do
      suspicious_state { "blocked" }
      flagged_at       { Time.current }
      flag_reason      { "suspicious activity" }
      flagged_by       { Trackguard::Visitor::FLAGGED_BY.first }
    end

    trait :suspicious do
      suspicious_state    { "suspicious" }
      suspicious_since_at { Time.current }
    end
  end
end
