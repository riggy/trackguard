FactoryBot.define do
  factory :page_view, class: "Trackguard::PageView" do
    association :visitor
    path       { "/posts/hello" }
    session_id { SecureRandom.hex(8) }
    referer    { "https://example.com" }
    user_agent { "Mozilla/5.0" }
    trace_id   { SecureRandom.hex(8) }
    created_at { Time.current }

    trait :with_source do
      source { "linkedin" }
    end
  end
end
