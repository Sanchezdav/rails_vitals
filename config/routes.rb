RailsVitals::Engine.routes.draw do
  root to: "dashboard#index"

  resources :requests, only: [ :index, :show ]
  resources :models, only: [ :index ]
  get "heatmap", to: "heatmap#index", as: :heatmap
end
