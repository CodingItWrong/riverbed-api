class CardsController < ApplicationController
  before_action :doorkeeper_authorize!
end
