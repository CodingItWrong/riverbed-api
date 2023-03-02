module Custom
  class LinksController < ActionController::Base
    def create
      # TODO: check API key (maybe store as a one-to-many off user)
      ParseLinkJob.parse(link_params)
      head :no_content
    end

    private

    def link_params
      params.permit(:url, :title)
    end
  end
end
