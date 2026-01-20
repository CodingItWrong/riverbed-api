class CardsController < JsonapiController
  before_action :doorkeeper_authorize!
end
