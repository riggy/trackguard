Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  scope :admin do
    resource :dashboard, only: :show
    patch "visitors/flag",        to: "visitors#flag",              as: :flag_visitor
    patch "visitors/unflag",      to: "visitors#unflag",            as: :unflag_visitor
    patch "visitors/whitelist",   to: "whitelisted_ips#create",     as: :whitelist_visitor
    patch "visitors/unwhitelist", to: "whitelisted_ips#destroy",    as: :unwhitelist_visitor
  end
end
