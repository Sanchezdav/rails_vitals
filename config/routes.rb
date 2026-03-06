RailsVitals::Engine.routes.draw do
  root to: "dashboard#index"

  resources :requests, only: [:index, :show]
end
