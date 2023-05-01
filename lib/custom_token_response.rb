# see https://github.com/doorkeeper-gem/doorkeeper/wiki/Customizing-Token-Response
module CustomTokenResponse
  def body
    super.merge("user_id" => @token.resource_owner_id)
  end
end
