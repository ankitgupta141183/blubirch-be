class Api::V1::Pos::DealerCustomersController < ApplicationController

  def get_dealer_customer
    @dealer_customer = DealerCustomer.filter(filtering_params).order('id desc')
    render json: @dealer_customer
  end

  private

    def filtering_params
      params.slice(:name, :phone_number, :email, :gst_number)
    end
end
