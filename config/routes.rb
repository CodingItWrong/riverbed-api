# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper

  jsonapi_resources :cards, only: %w[index create update destroy]
  jsonapi_resources :fields, only: %w[index]
  jsonapi_resources :users, only: %w[create]
end
