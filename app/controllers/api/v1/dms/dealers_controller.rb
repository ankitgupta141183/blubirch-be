class Api::V1::Dms::DealersController < ApplicationController
  before_action :set_dealer, only: [:show, :update, :destroy]

  # GET /dealers
  def index
    @dealers = Dealer.all

    render json: @dealers
  end

  # GET /dealers/1
  def show
    render json: @dealer
  end

  # POST /dealers
  def create
    @dealer = Dealer.new(dealer_params)
    dealer_status = LookupValue.where(code: Rails.application.credentials.dealer_status_pending_submission).first
    @dealer.status_id = dealer_status.id
    @dealer.status = dealer_status.original_code
    if @dealer.save
      render json: @dealer, status: :created
    else
      render json: @dealer.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /dealers/1
  def update
    if params[:dealer][:status] == 'Approved'
      dealer_status = LookupValue.where(code: Rails.application.credentials.dealer_status_approved).first
      @dealer.status_id = dealer_status.id
      @dealer.status = dealer_status.original_code
      dealer_user = DealerUser.where(dealer_id: @dealer.id).last
      if dealer_user.blank?
         DealerUser.create_dealer_user(@dealer.id)
      end
    elsif params[:dealer][:status] == 'Rejected'
      dealer_status = LookupValue.where(code: Rails.application.credentials.dealer_status_rejected).first
      @dealer.status_id = dealer_status.id
      @dealer.status = dealer_status.original_code
    else
      dealer_status = LookupValue.where(code: Rails.application.credentials.dealer_status_pending_approval).first
      @dealer.status_id = dealer_status.id
      @dealer.status = dealer_status.original_code
    end 
    if @dealer.update(dealer_params)
        
      render json: @dealer
    else
      render json: @dealer.errors, status: :unprocessable_entity
    end
  end

  # DELETE /dealers/1
  def destroy
    @dealer.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dealer
      @dealer = Dealer.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def dealer_params
      params.require(:dealer).permit(:dealer_code , :company_name, :first_name, :last_name, :email, :phone_number, :dealer_type_id, :dealer_type, :gst_number, :pan_number, :cin_number, :account_number, :bank_name, :ifsc_code, :address_1, :address_2, :city_id, :city, :state_id, :state, :country_id, :country, :pincode, :status_id, :status, :ancestry, :onboarded_user_id, :onboarder_by, :onboarded_employee_code, :onboarded_employee_phone_no, :deleted_at)
    end
end


