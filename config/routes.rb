Rails.application.routes.draw do
  use_doorkeeper

  jsonapi_resources :users, only: %w[create show update destroy]

  jsonapi_resources :boards, only: %w[index show create update destroy] do
    jsonapi_related_resources :cards
    jsonapi_related_resources :columns
    jsonapi_related_resources :elements
  end

  jsonapi_resources :cards, only: %w[show create update destroy]
  jsonapi_resources :columns, only: %w[show create update destroy]
  jsonapi_resources :elements, only: %w[show create update destroy]

  # iOS share integration
  resources :shares, only: %w[create]
end
