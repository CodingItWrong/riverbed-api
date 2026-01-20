class UsersController < JsonapiController
  before_action :doorkeeper_authorize!, except: [:create]
end
