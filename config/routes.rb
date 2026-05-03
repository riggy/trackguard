Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  scope "/admin", module: "admin" do
    resource  :dashboard, only: :show
    resource  :analytics, only: :show
    resources :visits,              only: :index
    resources :blocked_user_agents, only: %i[index create]
    patch "visitors/flag",        to: "visitors#flag",              as: :flag_visitor
    patch "visitors/unflag",      to: "visitors#unflag",            as: :unflag_visitor
    patch "visitors/whitelist",   to: "whitelisted_ips#create",     as: :whitelist_visitor
    patch "visitors/unwhitelist", to: "whitelisted_ips#destroy",    as: :unwhitelist_visitor
  end
end
