FactoryBot.define do
  factory :page_view, class: "Trackguard::PageView" do
    association :visitor
    path       { "/posts/hello" }
    session_id { SecureRandom.hex(8) }
    referer    { "https://example.com" }
    user_agent { "Mozilla/5.0" }
    trace_id       { SecureRandom.hex(8) }
    created_at     { Time.current }
    tracking_layer { nil }

    trait :js do
      tracking_layer { "js" }
    end

    trait :backend do
      tracking_layer { "backend" }
    end

    trait :with_source do
      source { "linkedin" }
    end
  end
end
