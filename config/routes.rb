Rails.application.routes.draw do
  post "/page_views", to: "trackguard/page_views#create"
end
