# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper

  jsonapi_resources :cards
  jsonapi_resources :fields
  jsonapi_resources :users, only: %w[create]
end
