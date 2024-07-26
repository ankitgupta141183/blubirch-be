class Api::V1::LogisticsPartnersController < ApplicationController
  def index
    set_pagination_params(params)
    @logistics_partners = LogisticsPartner.order('id desc').page(@current_page).per(@per_page)
    msg = 'Logistic Partners Fetched Successfully!'
    msg = 'No logistic parnter found' if @logistics_partners.blank?
    common_response(msg, 200, 'logistics_partners', @logistics_partners, true)
    # render json: @logistics_partners, meta: pagination_meta(@logistics_partners)
  end

  private
  # overriding controllers method as it will be easy to modify
  def permissions
    {
      superadmin: {
        "api/v1/logistics_partners": [:index]
      },
      central_admin: {
        "api/v1/logistics_partners": [:index]
      },
      site_admin: {
        "api/v1/logistics_partners": [:index]
      },
      default_user: {
        "api/v1/logistics_partners": [:index]
      },
      inwarder: {
        "api/v1/logistics_partners": [:index]
      },
      grader: {
        "api/v1/logistics_partners": [:index]
      }
    }
  end
end
