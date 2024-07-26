class Api::V1::Pos::CustomerInformationsController < ApplicationController
  before_action :set_customer_information, only: [:show, :update, :destroy]

  # GET /customer_informations
  def index
    @customer_informations = CustomerInformation.all

    render json: @customer_informations
  end

  # GET /customer_informations/1
  def show
    render json: @customer_information
  end

  # POST /customer_informations
  def create
    @customer_information = CustomerInformation.new(customer_information_params)

    if @customer_information.save
      render json: @customer_information, status: :created, location: @customer_information
    else
      render json: @customer_information.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /customer_informations/1
  def update
    if @customer_information.update(customer_information_params)
      render json: @customer_information
    else
      render json: @customer_information.errors, status: :unprocessable_entity
    end
  end

  # DELETE /customer_informations/1
  def destroy
    @customer_information.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_customer_information
      @customer_information = CustomerInformation.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def customer_information_params
      params.require(:customer_information).permit(:phone_number, :email_id, :name, :code, :location, :gst, :customer_type)
    end
end
