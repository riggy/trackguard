Trackguard::Engine.routes.draw do
  post "/page_views", to: "page_views#create"

  scope :admin do
    resource :dashboard, only: :show
    resources :visitors, only: [] do
      member do
        patch :flag
        patch :unflag
      end
    end
  end
end
