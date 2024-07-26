class Api::V1::Return::InitiationsController < ApplicationController

  skip_before_action :check_permission

  def index
  	returns = ReturnItem.all 
  	render json: returns
  end

end
