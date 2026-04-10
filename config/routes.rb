Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  resource :dashboard, only: :show
end
