class Admin::InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :update, :destroy]

  def index
    set_pagination_params(params)
    @invoices = Invoice.filter(filtering_params).order('id desc').page(@current_page).per(@per_page)
    render json: @invoices, meta: pagination_meta(@invoices)
  end

  def show
    render json: @invoice
  end

  def create
    @invoice = Invoice.new(invoice_params)
    @invoice.details = params[:invoice][:details] 
    if @invoice.save
      render json: @invoice, status: :created
    else
      render json: @invoice.errors, status: :unprocessable_entity
    end
  end

  def update
    @invoice = Invoice.find(params[:id])
    if @invoice.update(invoice_params)
      render json: @invoice
    elsif params[:invoice][:details].present?
      @invoice.details = params[:invoice][:details]
      render json: @invoice
    else
      render json: @invoice.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
  end

  def import 
    @invoices = Invoice.import(params[:file])
    render json: @invoices
  end

  private
    def set_invoice
      @invoice = Invoice.find(params[:id])
    end

    def invoice_params
      params.require(:invoice).permit(:client_id, :distribution_center_id, :invoice_number, :deleted_at, details: {})
    end

    def filtering_params
      params.slice(:distribution_center_id,:invoice_number)
    end
end
