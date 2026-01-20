class ColumnsController < JsonapiController
  before_action :doorkeeper_authorize!
end
