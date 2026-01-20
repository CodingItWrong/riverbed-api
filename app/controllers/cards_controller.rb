class CardsController < JsonapiResourcesController
  before_action :doorkeeper_authorize!
end
