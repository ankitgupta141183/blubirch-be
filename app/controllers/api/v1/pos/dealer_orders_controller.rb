class Api::V1::Pos::DealerOrdersController < ApplicationController
  before_action :set_dealer_order, only: [:show, :update, :destroy]

  # GET /dealer_orders
  def index
    @dealer_orders = DealerOrder.all

    render json: @dealer_orders
  end

  # GET /dealer_orders/1
  def show
    render json: @dealer_order
  end

  # POST /dealer_orders
  def create
    begin
      @dealer_order = DealerOrder.new(dealer_order_params)
      @dealer_order.order_number = DealerOrder.generate_order_number
      @dealer_order.assign_status
      @dealer_order.assign_dealer_details(@current_user.id)
      ActiveRecord::Base.transaction do
        if @dealer_order.save
          params[:dealer_order][:dealer_order_items].each do |item|
            item.each do |k,v|
              client_sku_master = ClientSkuMaster.where(code: k).last
              @dealer_order.dealer_order_items.create(
                client_sku_master_id: client_sku_master.id,
                mrp: client_sku_master.description["mrp"],
                sku_master_code: client_sku_master.code,
                item_description: client_sku_master.description["item_description"],
                discount_percentage: client_sku_master.description["discount_percentage"],
                discount_price: client_sku_master.description["discount_price"],
                unit_price: client_sku_master.description["unit_price"],
                quantity: v
              )
            end
          end
          @dealer_order.update_order_amounts
          render json: @dealer_order, status: :created
        else
          render json: @dealer_order.errors, status: :unprocessable_entity
        end
      end
    rescue Exception => message
      render json: {error: message}.to_json, status: 500
    end
  end

  # PATCH/PUT /dealer_orders/1
  def update
    if @dealer_order.update(dealer_order_params)
      render json: @dealer_order
    else
      render json: @dealer_order.errors, status: :unprocessable_entity
    end
  end

  # DELETE /dealer_orders/1
  def destroy
    @dealer_order.destroy
  end

  def get_client_sku_master
    @client_sku_masters = ClientSkuMaster.filter(filtering_params).order('id desc')
    render json: @client_sku_masters
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dealer_order
      @dealer_order = DealerOrder.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def dealer_order_params
      params.require(:dealer_order).permit(:dealer_code, :dealer_name, :dealer_city, :dealer_state, :dealer_country, :dealer_pincode, :client_id, :dealer_id, :dealer_phone_number, :dealer_email, :quantity, :total_amount, :discount_percentage, :discount_amount, :order_amount, :order_number, :status_id, :status, :approved_quantity, :rejected_quantity, :approved_amount, :rejected_amount, :approved_discount_percentage, :approved_discount_amount, :remarks, :user_id, :invoice_number, :invoice_attachement_file_type, :invoice_attachement_file, :invoice_user_id, :box_count, :received_box_count, :not_received_box_count, :excess_box_count, :sent_inventory_count, :received_inventory_count, :excess_inventory_count, :not_received_inventory_count, :dispatch_count, dealer_order_items_attributes: [:dealer_order_id, :mrp, :client_sku_master_id, :sku_master_code, :item_description, :discount_percentage, :discount_price, :unit_price, :quantity, :dispatched_quantity, :received_quantity, :processed_quantity, :processed_discount_price, :processed_discount_percentage, :total_amount])
    end

    def filtering_params
      params.slice(:code, :item_description)
    end
end
