Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  
  root "home#index"
  post "/home/analyze", to: "home#analyze"
  resources :home, only: [:index]
end
