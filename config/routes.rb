Rails.application.routes.draw do
  post "/page_views", to: "page_views#create"
end
