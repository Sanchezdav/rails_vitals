RailsVitals::Engine.routes.draw do
  root to: "dashboard#index"

  resources :requests, only: [ :index, :show ]
  resources :models, only: [ :index ]
  resources :n_plus_ones, only: [ :index, :show ]
  get "heatmap", to: "heatmap#index", as: :heatmap
end
