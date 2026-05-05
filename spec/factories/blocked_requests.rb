FactoryBot.define do
  factory :blocked_request, class: "Trackguard::BlockedRequest" do
    association :visitor
    path         { "/admin" }
    user_agent   { "ScannerBot/1.0" }
    http_method  { "GET" }
    block_reason { Trackguard::BlockedRequest::REASON_SCANNER }
    created_at   { Time.current }
  end
end
