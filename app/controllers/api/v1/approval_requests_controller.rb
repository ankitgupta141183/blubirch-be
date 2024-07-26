class Api::V1::ApprovalRequestsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:update]
	skip_before_action :check_permission

  before_action :set_approval_request, only: [:show, :edit, :update]

  before_action :get_approval_requests, :filter_by_status, :filter_by_rule_type, :filter_by_requested_disposition, :filter_by_requested_date, :filter_by_tag_number, only: :index

  def index
    render json: @approval_requests
  end

  def create
    @approval_request = ApprovalRequest.new(approval_request_params)
    if @approval_request.save

      render json: @approval_request, status: :created
    else
      render json: @approval_request.errors, status: :unprocessable_entity
    end
  end

  def show  
    render json: @approval_request
  end

  def edit
    render json: @approval_request
  end

  def update
    if @approval_request.update(approval_update_params)
      @approval_request.update!(status: :approved) if @approval_request.approved_on.present?
      @approval_request.update!(status: :rejected) if @approval_request.rejected_on.present?
      render json: @approval_request
    else
      render json: @approval_request.errors, status: :unprocessable_entity
    end
  end

  private

  def approval_request_params
    params.require(:approval_request).permit(:approvable_type, :approvable_id, :approval_configuration_id)
  end

  def approval_update_params
    params.require(:approval_request).permit(:approved_on, :rejected_on, approval_hash: {}, reject_hash: {})
  end

  def set_approval_request
    @approval_request = ApprovalRequest.find(params[:id])
  end

  def get_approval_requests
    @approval_requests = ApprovalRequest.all.order('updated_at desc')
  end

  def filter_by_status
    @approval_requests = @approval_requests.where(status: params[:status]) if params[:status].present?
  end

  def filter_by_rule_type
    @approval_requests = @approval_requests.where(approval_rule_type: params[:approval_rule_type]) if params[:approval_rule_type].present?
  end

  def filter_by_requested_disposition
    @approval_requests = @approval_requests.where("lower(approval_requests.details ->> 'requested_disposition') IN (?) ", params[:requested_disposition]) if params[:requested_disposition].present?
  end

  def filter_by_requested_date
    @approval_requests = @approval_requests.where("lower(approval_requests.details ->> 'requested_date') IN (?) ", params[:requested_date].to_date.to_s) if params[:requested_date].present?
  end

  def filter_by_tag_number
    @approval_requests = @approval_requests.where("lower(approval_requests.details ->> 'tag_number') IN (?) ", params[:tag_number]) if params[:tag_number].present?
  end

end
