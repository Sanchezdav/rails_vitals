RailsVitals::Engine.routes.draw do
  root to: "dashboard#index"

  resources :requests, only: [ :index, :show ]
  resources :models, only: [ :index ]
  resources :n_plus_ones, only: [ :index, :show ]
  resources :associations, only: [ :index ]
  resources :playgrounds, only: [ :index, :create ]
  get "heatmap", to: "heatmap#index", as: :heatmap
  get "requests/:request_id/explain/:query_index", to: "explains#show", as: :explain
end
