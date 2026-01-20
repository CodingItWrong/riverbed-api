# frozen_string_literal: true

class JsonapiResourcesController < ApplicationController
  include JSONAPI::ActsAsResourceController

  private

  def context = {current_user: current_user}
end
