module JSONAPI
  class ResourceController < ActionController::Base
    include JSONAPI::ActsAsResourceController
  end
end
