class ElementsController < JsonapiController
  before_action :doorkeeper_authorize!
end
