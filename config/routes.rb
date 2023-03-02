# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper

  jsonapi_resources :users, only: %w[create]

  jsonapi_resources :boards, only: %w[index show create update destroy] do
    jsonapi_related_resources :cards
    jsonapi_related_resources :columns
    jsonapi_related_resources :elements
  end

  jsonapi_resources :cards, only: %w[show create update destroy]
  jsonapi_resources :columns, only: %w[create update destroy]
  jsonapi_resources :elements, only: %w[create update destroy]

  # custom integrations that will ultimately be separate APIs that use this API's public interface
  namespace :custom do
    resources :links, only: %w[create]
  end
end
