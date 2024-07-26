class Admin::InvoiceInventoryDetailsController < ApplicationController
  before_action :set_invoice_inventory_detail, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @invoice_inventory_details = InvoiceInventoryDetail.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
      render json: @invoice_inventory_details, meta: pagination_meta(@invoice_inventory_details)
  end

  def show
    render json: @invoice_inventory_detail
  end

  def create
    @invoice_inventory_detail = InvoiceInventoryDetail.new(invoice_inventory_detail_params)

    if @invoice_inventory_detail.save
      render json: @invoice_inventory_detail, status: :created
    else
      render json: @invoice_inventory_detail.errors, status: :unprocessable_entity
    end
  end

  def update
    if @invoice_inventory_detail.update(invoice_inventory_detail_params)
      render json: @invoice_inventory_detail
    else
      render json: @invoice_inventory_detail.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice_inventory_detail.destroy
  end

  def import
    @invoice_inventory_details = InvoiceInventoryDetail.import(params[:file])
    render json: @invoice_inventory_details
  end

  private
    
    def set_invoice_inventory_detail
      @invoice_inventory_detail = InvoiceInventoryDetail.find(params[:id])
    end

    def invoice_inventory_detail_params
      params.require(:invoice_inventory_detail).permit(:invoice_id, :client_category_id, :client_sku_master_id, :details, :deleted_at)
    end

    def filtering_params
      params.slice(:invoice_id, :client_category_id, :client_sku_master_id)
    end
end
