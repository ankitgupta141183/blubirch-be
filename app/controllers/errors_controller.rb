class ErrorsController < ApplicationController
  rescue_from ActionController::RoutingError, with: :not_found
  skip_before_action :authenticate_user!
  skip_before_action :check_permission

  def not_found
    respond_to do |format|
      format.json { render json: { error: 'Route not found' }, status: :not_found }
      format.html do
        redirect_to request_base_url + "/404"
      end
    end
  end
end
