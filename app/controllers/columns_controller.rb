class ColumnsController < JSONAPI::ResourceController
  before_action :doorkeeper_authorize!
end
