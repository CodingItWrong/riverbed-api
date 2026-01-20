class ElementsController < JsonapiResourcesController
  before_action :doorkeeper_authorize!
end
