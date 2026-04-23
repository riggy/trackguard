Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  scope :admin do
    resource :dashboard, only: :show
    patch "visitors/flag",   to: "visitors#flag",   as: :flag_visitor
    patch "visitors/unflag", to: "visitors#unflag", as: :unflag_visitor
  end
end
