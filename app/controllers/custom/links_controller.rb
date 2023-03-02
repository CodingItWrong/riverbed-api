module Custom
  class LinksController < ActionController::Base
    before_action :verify_api_key

    def create
      ParseLinkJob.parse(link_params)
      head :no_content
    end

    private

    def user_for_api_key
      provided_header = request.headers["HTTP_AUTHORIZATION"]
      return nil unless provided_header.present?

      key = provided_header.gsub(/^Bearer /i, '')
      ApiKey.find_by(key:)
    end

    def verify_api_key
      head :unauthorized unless user_for_api_key.present?
    end

    def link_params
      params.permit(:url, :title)
    end
  end
end
