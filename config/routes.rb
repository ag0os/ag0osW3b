Rails.application.routes.draw do
  # One canonical host (PD-5): www answers every request with a 301 to the apex.
  constraints host: "www.agoos.dev" do
    match "(*path)", via: :all, to: redirect { |_params, request| "https://agoos.dev#{request.fullpath}" }
  end

  # Authentication (Rails 8 built-in generator)
  resource  :session
  resources :passwords, param: :token

  resource :locale, only: :update

  # Bare addresses negotiate; each language also has a stable public address.
  scope "(:locale)", locale: Regexp.union(I18n.available_locales.map(&:to_s)) do
    root "home#show"
    get "about", to: "pages#about"
    get "work", to: "pages#work"
    get "contact", to: "pages#contact"
    get "consulting", to: "pages#consulting"
    get "writing", to: "posts#index", as: :posts
    get "writing/:slug", to: "posts#show", as: :post
    # Unsupported feed formats are no address (WR-5).
    get "feed", to: "posts#feed", as: :feed, defaults: { format: "atom" }, constraints: { format: /atom|xml/ }
  end

  # Admin
  namespace :admin do
    root "dashboard#show"
    resources :posts
    resources :sections do
      patch :toggle, on: :member
    end
    resource :copy, only: %i[show update], controller: "copies"
    get   "settings", to: "site_settings#index",  as: :site_settings
    patch "settings", to: "site_settings#update", as: :update_site_settings
  end

  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
