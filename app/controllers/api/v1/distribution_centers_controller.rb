class Api::V1::DistributionCentersController < ApplicationController
  def index
    set_pagination_params(params)
    distribution_centers = current_user.distribution_centers.order('id desc')
    render json: distribution_centers, each_serializer: DistributionCenterLocationSerializer
  end

  private
  # overriding controllers method as it will be easy to modify
  def permissions
    {
      superadmin: {
        "api/v1/distribution_centers": [:index]
      },
      central_admin: {
        "api/v1/distribution_centers": [:index]
      },
      site_admin: {
        "api/v1/distribution_centers": [:index]
      },
      default_user: {
        "api/v1/distribution_centers": [:index]
      },
      inwarder: {
        "api/v1/distribution_centers": [:index]
      },
      grader: {
        "api/v1/distribution_centers": [:index]
      }
    }
  end
end
