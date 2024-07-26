class Api::V1::Warehouse::CompanyStocksController < ApplicationController
  before_action :set_company_stock, only: [:show, :update, :destroy]

  # GET /company_stocks
  def index
    @company_stocks = CompanyStock.all

    render json: @company_stocks
  end

  # GET /company_stocks/1
  def show
    render json: @company_stock
  end

  # POST /company_stocks
  def create
    @company_stock = CompanyStock.new(company_stock_params)

    if @company_stock.save
      render json: @company_stock, status: :created
    else
      render json: @company_stock.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /company_stocks/1
  def update
    if @company_stock.update(company_stock_params)
      render json: @company_stock
    else
      render json: @company_stock.errors, status: :unprocessable_entity
    end
  end

  def upload_stock
    company_stock = CompanyStock.import(params[:file])
    redirect_to  api_v1_warehouse_company_stocks_path, notice: "Stocks Imported"
  end

  # DELETE /company_stocks/1
  def destroy
    @company_stock.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_company_stock
      @company_stock = CompanyStock.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def company_stock_params
      params.require(:company_stock).permit(:client_id, :client_sku_master_id, :serial_number, :quantity, :sold_quantity, :sku_code, :category_id, :category_name, :item_description, :mrp, :brand, :model, :hsn_code, :tax_percentage, :location, :status_id, :status, :user_id, details: {})
    end
end
