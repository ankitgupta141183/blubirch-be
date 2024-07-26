class Api::V2::Warehouse::Liquidation::CompetitiveBiddingPriceController < Api::V2::Warehouse::LiquidationsController
  STATUS = 'Competitive Bidding Price'
  before_action :validate_lot_params, :validate_liquidations_in_lot, only: :create_lot
  before_action :set_liquidations, only: :move_to_moq

  def create_lot
    begin
      ActiveRecord::Base.transaction do
        @lot = LiquidationOrder.create_lot(lot_params, current_user)
        validate_create_lot
        render_success_message("Lot creation successful with the ID \"#{@lot.id}\" & updated in the ‘Pending B2B Publish’ page", :ok)
      end  
    rescue => e
      render_error(e.message, 500)
    end  
  end

  def move_to_moq
    status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_moq_price)
    update_liquidations_status(status: status.original_code, status_id: status.id)
  end

  # TODO This will be implemented in Phase II
  def auto_lot

  end

  def calculate_ai_price
    if params[:inventory_ids].present?
      ai_inventory = AiInventoryPricingService.new(params[:inventory_ids])
      errors = ai_inventory.validate_inventories
      if errors.present?
        render json: { errors: errors }
      else
        response = ai_inventory.call
        render json: { prices: ai_inventory.calculate_prices }
      end
    else
      raise CustomErrors.new  "Inventory Ids cant be blank"
    end
  end

  private

    def lot_params
      lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_competitive_lot)
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing)
      liquidation_ids = params[:liquidation_ids]
      details = {'approved_buyer_ids' => params[:approved_buyer_ids]}
      lot_params = {
                    lot: {
                      lot_name: params[:lot_name],
                      lot_desc: params[:lot_desc],
                      mrp: params[:lot_mrp],
                      end_date: params[:end_date],
                      start_date: params[:start_date],
                      status:lot_status.original_code,
                      status_id: lot_status.id,
                      order_amount: params[:lot_expected_price],
                      quantity: liquidation_ids&.count,
                      lot_type: lot_type.original_code,
                      lot_type_id: lot_type.id,
                      floor_price: params[:floor_price]&.to_f,
                      reserve_price: params[:reserve_price]&.to_f,
                      buy_now_price: params[:buy_now_price]&.to_f,
                      increment_slab: params[:increment_slab]&.to_i,
                      delivery_timeline: params[:delivery_timeline],
                      additional_info: params[:additional_info],
                      bid_value_multiple_of: params[:bid_value_multiple_of],
                      details: details,
                      created_by_id: current_user.id
                    },
                    images: params[:images],
                    removed_urls: params[:removed_urls],
                    image_urls: params[:image_urls],
                    liquidation_ids: liquidation_ids,
                  }
      return lot_params if params[:lot_file].blank?
      lot_params_from_file lot_params
    end

    def lot_params_from_file temp_lot_params
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_lot_details)
      lot_file = CSV.read(params[:lot_file].path, headers: true, header_converters: :symbol)
      liquidation_ids = lot_file[:article_id].map(&:strip)
      file_lot_params = temp_lot_params
      file_lot_params[:liquidation_ids] = liquidation_ids
      file_lot_params[:lot][:lot_name] = lot_file[:lot_name][0]
      file_lot_params[:lot][:lot_desc] = lot_file[:article_description][0]
      file_lot_params[:lot][:mrp] = lot_file[:mrp][0].to_f
      file_lot_params[:lot][:end_date] = lot_file[:end_date][0],
      file_lot_params[:lot][:start_date] = lot_file[:start_date][0],
      file_lot_params[:lot][:order_amount] = lot_file[:order_amount][0]
      file_lot_params[:lot][:quantity] = liquidation_ids.count
      file_lot_params[:lot][:floor_price] = lot_file[:floor_price][0]&.to_f
      file_lot_params[:lot][:reserve_price] = lot_file[:reserve_price][0]&.to_f
      file_lot_params[:lot][:buy_now_price] = lot_file[:buy_now_price][0]&.to_f
      file_lot_params[:lot][:increment_slab] = lot_file[:increment_slab][0]&.to_i
      file_lot_params[:lot][:bid_value_multiple_of] = lot_file[:bid_value_multiple_of][0]&.to_i
      file_lot_params[:lot][:lot_image_urls] = lot_file[:lot_image_urls][0]
      file_lot_params
    end

    def validate_lot_params
      required_params = {
        lot_name: "Missing required param 'lot_name'.",
        # lot_mrp: "Missing required param 'lot_mrp'.",
        start_date: "Missing required param 'start_date'.",
        end_date: "Missing required param 'end_date'.",
        # delivery_timeline: "Missing required param 'order_amount'.",
        floor_price: "Missing required param 'floor_price'.",
        reserve_price: "Missing required param 'reserve_price'.",
        buy_now_price: "Missing required param 'buy_now_price'.",
        increment_slab: "Missing required param 'increment_slab'."
      }
      required_params.each do |param, error_message|
        render_error(error_message, 422) and return if lot_params[:lot][param].blank?
      end
    end

    def validate_create_lot
      @lot.liquidations.reload

      unless mrp_greater_than_other_prices?
        raise CustomErrors.new "MRP should be more than all other prices."
      end

      unless validate_buy_now_price
        raise CustomErrors.new  "BuyNowPrice should be more (reverse and floor price) and it should be less than mrp."
      end
    end

    def mrp_greater_than_other_prices?
      mrp = @lot.mrp
      mrp >= @lot.buy_now_price &&
      mrp >= @lot.reserve_price &&
      mrp >= @lot.floor_price
    end

    def validate_buy_now_price
      buy_now_price = @lot.buy_now_price
      buy_now_price <= @lot.mrp &&
      buy_now_price >= @lot.reserve_price &&
      buy_now_price >= @lot.floor_price
    end
end
