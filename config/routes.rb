Rails.application.routes.draw do
  mount JasmineRails::Engine => '/specs' if defined?(JasmineRails)
  root "videos#index"

  # add more routes here

  resources :videos, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  resources :videos, only: [] do
    resources :comments, only: [:create]
  end

  namespace :api do
    namespace :v1 do
      resources :comments, only: [:index, :show, :create]
    end
  end
end
