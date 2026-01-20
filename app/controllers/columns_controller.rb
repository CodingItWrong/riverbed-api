class ColumnsController < JsonapiResourcesController
  before_action :doorkeeper_authorize!
end
