class Api::V2::Warehouse::LiquidationOrder::B2c::InProgressController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = "In Progress B2C"

  #before_action :check_for_liquidation_order_params, only: :delete_lots
  #before_action :set_liquidation_orders, only: [:delete_lots]
  before_action :get_ecom_liquidations, :filter_data, only: :index

  def index
    @liquidation_orders = @liquidation_orders.page(@current_page).per(@per_page)
    render_collection(@liquidation_orders, Api::V2::Warehouse::EcomLiquidationSerializer)
  end

  def update_sales
    purchase_history_details = params["ecom_purchase_history"]
    ecom_liquidations = EcomLiquidation.where(id: purchase_history_details["ecom_liquidation_ids"].to_s.split(','))
    ecom_liquidation_ids = []
    ActiveRecord::Base.transaction do 
      ecom_liquidations.each do |ecom_liquidation|
        next if ecom_liquidation.quantity.to_f <= 0.0
        ecom_purchase_history = ecom_liquidation.ecom_purchase_histories.new(ecom_purchase_history_params)
        ecom_purchase_history.status = :ordered
        ecom_purchase_history.quantity = ecom_liquidation.quantity
        ecom_purchase_history.amount = ecom_liquidation.amount
        ecom_purchase_history.save!
        ecom_liquidation.quantity -= ecom_purchase_history.quantity
        raise "quantity cannot be negative" if ecom_liquidation.quantity.negative?
        ecom_liquidation.save!
        ecom_liquidation_ids << ecom_liquidation.id
      end
    end
    render_success_message("Successfully Createad Ecom Purchase History for ecom liquidation ids #{ecom_liquidation_ids.join(',')}", :ok)
  end

  def delete_lots
    ecom_liquidations = EcomLiquidation.where(id: params["ecom_liquidation_ids"].to_s.split(','))
    raise "No Data Present" if ecom_liquidations.blank?
    liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_pending_b2c_publish)
    destroyed_ecom_liquidation_count = []
    begin
      url = Rails.application.credentials.bmaxx_url + '/rims/items/destroy_product'
      payload = { item_ids: ecom_liquidations.pluck(:external_request_id).join(',') }
      response = EcomLiquidation.send_request_ext_platform('delete', url, payload)
      if  response.code == 200
        item_ids = JSON.parse(response.body)["item_ids"].to_s.split(',')
        new_ecom_liquidations = ecom_liquidations.where(external_request_id: item_ids)
        new_ecom_liquidations.each do |ecom_liquidation|
          ecom_liquidation.liquidation.update!(b2c_publish_status: nil, status: liquidation_status.original_code, status_id: liquidation_status.id)   
          ecom_liquidation.liquidation.inventory.update_inventory_status!(liquidation_status)
          destroyed_ecom_liquidation_count << ecom_liquidation.id
          ecom_liquidation.destroy
        end
      end
    rescue => e
      raise e.message and return
    end
    render_success_message("#{destroyed_ecom_liquidation_count.count} ecom liquidations are destroyed", :ok)
  end

  private

    def ecom_purchase_history_params
      params.require(:ecom_purchase_history).permit(:order_number, :username, :address_1, :address_2, :city, :state)
    end

    def get_ecom_liquidations
      @liquidation_orders = EcomLiquidation.where(status: "In Progress B2C").order('ecom_liquidations.updated_at desc')
    end

    def filter_data
      @liquidation_orders = @liquidation_orders.where(inventory_sku: params['article_id'].split_with_gsub) if params['article_id'].present?
      @liquidation_orders = @liquidation_orders.where(platform: params['platform'].split_with_gsub) if params['platform'].present?
      @liquidation_orders = @liquidation_orders.where(grade: params['grade'].split_with_gsub) if params['grade'].present?
    end
end
