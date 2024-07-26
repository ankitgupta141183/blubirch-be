class Api::V1::ApprovalConfigurationsController < ApplicationController
	skip_before_action :check_permission

  before_action :set_approval_configuration, only: [:show, :edit, :update]

  def create
    @approval_configuration = ApprovalConfiguration.new(approval_params)
    if @approval_configuration.save

      render json: @approval_configuration, status: :created
    else
      render json: @approval_configuration.errors, status: :unprocessable_entity
    end
  rescue Exception => e
    render json: e.message, status: :unprocessable_entity
  end

  def show
    render json: @approval_configuration
  end

  def edit
    render json: @approval_configuration
  end

  def update
    if @approval_configuration.update(approval_params)
      render json: @approval_configuration
    else
      render json: @approval_configuration.errors, status: :unprocessable_entity
    end
  end

  private

  def approval_params
    params.require(:approval).permit(:approval_name, :approval_config_type, :approval_flow, :approval_count, 
      approval_users_attributes: [:user_id, :heirarchy_level])
  end

  def set_approval_configuration
    @approval_configuration = ApprovalConfiguration.find(params[:id])
  end
end
