class Api::V1::Pos::StockSkusController < ApplicationController
  before_action :set_stock_sku, only: [:show, :update, :destroy]

  # GET /stock_skus
  def index
    @stock_skus = StockSku.all

    render json: @stock_skus
  end

  # GET /stock_skus/1
  def show
    render json: @stock_sku
  end

  # POST /stock_skus
  def create
    @stock_sku = StockSku.new(stock_sku_params)

    if @stock_sku.save
      render json: @stock_sku, status: :created, location: @stock_sku
    else
      render json: @stock_sku.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /stock_skus/1
  def update
    if @stock_sku.update(stock_sku_params)
      render json: @stock_sku
    else
      render json: @stock_sku.errors, status: :unprocessable_entity
    end
  end

  # DELETE /stock_skus/1
  def destroy
    @stock_sku.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stock_sku
      @stock_sku = StockSku.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def stock_sku_params
      params.require(:stock_sku).permit(:sku_code, :quantity, :item_name, :category_name, :mrp, :discount_percentage, :discount_price, :gst, :image_url, :last_30_days_quantity)
    end
end
