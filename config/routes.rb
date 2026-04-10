Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  scope :admin do
    resource :dashboard, only: :show
  end
end
