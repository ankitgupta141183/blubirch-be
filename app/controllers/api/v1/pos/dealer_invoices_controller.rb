class Api::V1::Pos::DealerInvoicesController < ApplicationController
  before_action :set_dealer_invoice, only: [:show, :update, :destroy]

  # GET /dealer_invoices
  def index
    @dealer_invoices = DealerInvoice.all

    render json: @dealer_invoices
  end

  # GET /dealer_invoices/1
  def show
    render json: @dealer_invoice
  end

  # POST /dealer_invoices
  def create
    begin
      @dealer_invoice = DealerInvoice.new(dealer_invoice_params)
      @dealer_invoice.invoice_number = DealerInvoice.generate_invoice_number
      @dealer_invoice.user_id = current_user.id
      # @dealer_invoice.assign_status
      @dealer_invoice.assign_dealer_details(params[:dealer_invoice][:dealer_id])
      @dealer_invoice.assign_payment(params[:dealer_invoice][:payment_mode_id])
      ActiveRecord::Base.transaction do
        if @dealer_invoice.save
          params[:dealer_invoice][:dealer_invoice_items].each do |item|
            item.each do |k,v|
              dealer_order_inventory = DealerOrderInventory.where(sku_master_code: k).last
              @dealer_invoice.dealer_invoice_items.create(
                dealer_order_inventory_id: dealer_order_inventory.try(:id),
                sku_master_code: dealer_order_inventory.try(:sku_master_code),
                item_description: dealer_order_inventory.try(:item_description),
                mrp: dealer_order_inventory.try(:mrp),
                serial_number: dealer_order_inventory.try(:serial_number),
                client_sku_master_id: dealer_order_inventory.try(:client_sku_master_id),
                # hsn_code: dealer_order_inventory.hsn_code,
                # discount_percentage: dealer_order_inventory.discount_percentage,
                # discount_price: dealer_order_inventory.discount_price,
                unit_price: dealer_order_inventory.try(:unit_price),
                quantity: v
                # central_tax_percentage: DealerInvoice.tax_percentage_values[:central_tax_percentage],
                # central_tax_amount: (dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:central_tax_percentage])/100.to_f,
                # state_tax_percentage: DealerInvoice.tax_percentage_values[:state_tax_percentage],
                # state_tax_amount: (dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:state_tax_percentage])/100.to_f,
                # inter_state_tax_percentage: DealerInvoice.tax_percentage_values[:inter_state_tax_percentage],
                # inter_state_tax_amount: (dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:inter_state_tax_percentage])/100.to_f,
                # total_amount: dealer_order_inventory.unit_price+((dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:central_tax_percentage])/100.to_f)+((dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:state_tax_percentage])/100.to_f)+((dealer_order_inventory.unit_price*DealerInvoice.tax_percentage_values[:inter_state_tax_percentage])/100.to_f)
              )
            end
          end
          if params[:dealer_invoice][:dealer_customer_id].blank?
            dealer_customer = DealerCustomer.create(params[:dealer_invoice][:dealer_customer])
            @dealer_invoice.assign_dealer_customer_details(dealer_customer.id)
          else
            @dealer_invoice.assign_dealer_customer_details(params[:dealer_invoice][:dealer_customer_id])
          end
          @dealer_invoice.update_order_amounts
          render json: @dealer_invoice, status: :created
        else
          render json: @dealer_invoice.errors, status: :unprocessable_entity
        end
      end
    rescue Exception => message
      render json: {error: message}.to_json, status: 500
    end
  end

  # PATCH/PUT /dealer_invoices/1
  def update
    if @dealer_invoice.update(dealer_invoice_params)
      render json: @dealer_invoice
    else
      render json: @dealer_invoice.errors, status: :unprocessable_entity
    end
  end

  # DELETE /dealer_invoices/1
  def destroy
    @dealer_invoice.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dealer_invoice
      @dealer_invoice = DealerInvoice.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def dealer_invoice_params
      params.require(:dealer_invoice).permit(:dealer_id, :dealer_customer_id, :customer_code, :customer_name, :customer_phone_number, :customer_email, :customer_company_name, :customer_address_1, :customer_address_2, :customer_city, :customer_state, :customer_country, :customer_pincode, :customer_gst, :dealer_company_name, :dealer_address_1, :dealer_address_2, :dealer_city, :dealer_state, :dealer_country, :dealer_pincode, :dealer_gst, :dealer_pan, :dealer_cin, :quantity, :total_amount, :discount_percentage, :discount_amount, :tax_amount, :amount, :invoice_number, :status_id, :status, :user_id, :payment_mode_id, :payment_mode, :payment_id_proof_number, :coupon_id, :coupon_code, :coupon_discount_percentage)
    end
end
