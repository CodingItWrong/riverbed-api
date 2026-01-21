Rails.application.routes.draw do
  use_doorkeeper

  resources :boards, only: %w[index show create update destroy] do
    resources :columns, only: %w[index]
    resources :elements, only: %w[index]
  end
  resources :columns, only: %w[show create update destroy]
  resources :elements, only: %w[show create update destroy]
  resources :users, only: %w[create show update destroy]

  # Nested board resources still use jsonapi_resources for now
  jsonapi_resources :boards, only: [] do
    jsonapi_related_resources :cards
  end

  jsonapi_resources :cards, only: %w[show create update destroy]

  # iOS share integration
  resources :shares, only: %w[create]
end
