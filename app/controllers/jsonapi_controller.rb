# frozen_string_literal: true

class JsonapiController < ApplicationController
  include JSONAPI::ActsAsResourceController

  private

  def context = {current_user: current_user}
end
