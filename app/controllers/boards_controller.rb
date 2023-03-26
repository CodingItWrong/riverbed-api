class BoardsController < ApplicationController
  before_action :doorkeeper_authorize!
end
