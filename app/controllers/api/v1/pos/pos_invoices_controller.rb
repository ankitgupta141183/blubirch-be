class Api::V1::Pos::PosInvoicesController < ApplicationController
  before_action :set_pos_invoice, only: [:show, :update, :destroy]

  # GET /pos_invoices
  def index
    @pos_invoices = PosInvoice.all

    render json: @pos_invoices
  end

  # GET /pos_invoices/1
  def show
    render json: @pos_invoice
  end

  # POST /pos_invoices
  def create
    params.permit!
    all_invoices = []
    begin
      PosInvoice.transaction do
        params[:pos_invoices].each do |pos_invoice|
          pos_invoice = PosInvoice.new(pos_invoice[:pos_invoice])
          pos_invoice.save!
          all_invoices << pos_invoice
        end
      end
      render json: all_invoices
    rescue Exception => message
      render json: {error: message}.to_json, status: 500
    end
  end

  # PATCH/PUT /pos_invoices/1
  def update
    if @pos_invoice.update(pos_invoice_params)
      render json: @pos_invoice
    else
      render json: @pos_invoice.errors, status: :unprocessable_entity
    end
  end

  # DELETE /pos_invoices/1
  def destroy
    @pos_invoice.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_pos_invoice
      @pos_invoice = PosInvoice.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def pos_invoice_params
      params.require(:pos_invoice).permit(:invoice_number, :customer_name, :customer_phone, :customer_email, :customer_code, :customer_location, :total_quantity, :amount, :tax_amount, :discount_percentage, :applied_coupon_code, :total_amount, :sku_code, :item_name, :mrp, :discounted_price, :quantity, :invoice_type)
    end
end
