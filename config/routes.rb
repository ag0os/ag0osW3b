Rails.application.routes.draw do
  # Authentication (Rails 8 built-in generator)
  resource  :session
  resources :passwords, param: :token

  # Public site
  root "home#show"
  get "about",   to: "pages#about"
  get "work",    to: "pages#work"
  get "contact", to: "pages#contact"

  # Blog
  get "writing",       to: "posts#index", as: :posts
  get "writing/:slug", to: "posts#show",  as: :post

  # Admin
  namespace :admin do
    root "dashboard#show"
    resources :posts
    resources :sections do
      patch :toggle, on: :member
    end
    get   "settings", to: "site_settings#index",  as: :site_settings
    patch "settings", to: "site_settings#update", as: :update_site_settings
  end

  # Health check for load balancers / uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
