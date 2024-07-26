class Api::V2::BuyerMastersController < ApplicationController
  skip_before_action :authenticate_user!, :check_permission

  def create
    if buyer_params[:username].present?
      buyer_master = BuyerMaster.unscoped.find_or_initialize_by(username: buyer_params[:username])
      buyer_master.update(buyer_params)
    end
    render_success_message('Buyer info received.', :ok)
  end

  private

  def buyer_params
    params.permit(:username, :email, :first_name, :last_name, :is_active, :organization_id, :organization_name)
  end
end
