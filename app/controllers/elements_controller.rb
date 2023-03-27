class ElementsController < ApplicationController
  before_action :doorkeeper_authorize!
end
