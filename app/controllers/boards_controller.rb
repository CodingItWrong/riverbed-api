class BoardsController < JsonapiController
  before_action :doorkeeper_authorize!
end
