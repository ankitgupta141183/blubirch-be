class Api::V1::VendorMastersController < ApplicationController
  def index
    set_pagination_params(params)
    vendor_masters = VendorMaster
    vendor_masters = vendor_masters.search_by_text(params[:search]) if params[:search].present?
    vendor_masters = vendor_masters.order('id desc').page(@current_page).per(@per_page)
    render json: vendor_masters, each_serializer: VendorMasterListSerializer, meta: pagination_meta(vendor_masters)
  end

  private
  # overriding controllers method as it will be easy to modify
  def permissions
    {
      superadmin: {
        "api/v1/vendor_masters": [:index]
      },
      central_admin: {
        "api/v1/vendor_masters": [:index]
      },
      site_admin: {
        "api/v1/vendor_masters": [:index]
      },
      default_user: {
        "api/v1/vendor_masters": [:index]
      }
    }
  end
end
