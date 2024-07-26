class Admin::CustomerReturnReasonsController < ApplicationController
  before_action :set_customer_return_reason, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @customer_return_reasons = CustomerReturnReason.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @customer_return_reasons, meta: pagination_meta(@customer_return_reasons)
  end

  def show
    render json: @customer_return_reason
  end

  def create
    @customer_return_reason = CustomerReturnReason.new(customer_return_reason_params)

    if @customer_return_reason.save
      render json: @customer_return_reason, status: :created
    else
      render json: @customer_return_reason.errors, status: :unprocessable_entity
    end
  end

  def update
    if @customer_return_reason.update(customer_return_reason_params)
      render json: @customer_return_reason
    else
      render json: @customer_return_reason.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @customer_return_reason.destroy
  end

  def import
    @customer_return_reason = CustomerReturnReason.import(params[:file])
    render json: @customer_return_reason
  end

  private
    def set_customer_return_reason
      @customer_return_reason = CustomerReturnReason.find(params[:id])
    end

    def customer_return_reason_params
      params.require(:customer_return_reason).permit(:name, :grading_required, :deleted_at)
    end

    def filtering_params
      params.slice(:name,:grading_required)
    end
end
