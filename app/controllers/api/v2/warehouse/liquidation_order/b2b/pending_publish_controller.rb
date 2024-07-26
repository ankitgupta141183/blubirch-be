class Api::V2::Warehouse::LiquidationOrder::B2b::PendingPublishController < Api::V2::Warehouse::LiquidationOrdersController
  STATUS = ["Ready for publishing", "Pending lot details", "Publish Initiated", "Publish Error", "Ready For Republishing", "Creating Sub Lots"]

  before_action :check_for_liquidation_order_params, only: [:update_timing, :delete_lots]
  before_action :set_liquidation_orders, only: [:update_timing, :delete_lots]
  before_action :set_liquidation_order, only: [:lot_details, :update, :lot_images, :show, :remove_lot_items]
  before_action :validate_moq_lot_params, :validate_inventory_grade_mapping, only: [:update, :remove_lot_items]
  before_action :validate_publish_lot, only: [:publish]

  def update_timing
    update_bid_timing
  end

  def delete_lots
    remove_lots
  end

  def lot_details
    serializer = @liquidation_order.is_moq_lot? ? Api::V2::Warehouse::MoqLotDetailSerializer : Api::V2::Warehouse::LotDetailSerializer
    render_resource(@liquidation_order, serializer)
  end

  def remove_lot_items
    ActiveRecord::Base.transaction do
      if @liquidation_order.is_moq_lot?
        @liquidation_order.details['items_deleted'] = true
        @liquidation_order.details['approved_buyer_ids'] = @liquidation_order.details_was['approved_buyer_ids']
        @liquidation_order.save!
        liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_moq_price)
        liquidations = @liquidation_order.liquidations
        update_liquidation(liquidations, liquidation_status)
        @moq_lot_params[:lot].merge!({
          lot_name: @liquidation_order.lot_name.split(' || ').slice(0...-1).join(' || '),
          lot_desc: @liquidation_order.lot_desc,
          end_date: @liquidation_order.end_date,
          start_date: @liquidation_order.start_date,
          delivery_timeline: @liquidation_order.delivery_timeline,
          maximum_lots_per_buyer: @liquidation_order.maximum_lots_per_buyer,
          details: @liquidation_order.details,
          created_by_id: @liquidation_order.created_by_id || current_user.id,
          updated_by_id: current_user.id
        })
        @parent_lot = LiquidationOrder.create_lot(@moq_lot_params, current_user)
        @parent_lot.create_sub_lots_and_prices(@moq_lot_params, current_user)
        @liquidation_order.destroy
        render_success_message("Successfully updated!", :ok)
      else
        liquidations = Liquidation.where(tag_number: params["remove_tag_numbers"])
        if liquidations.present?
          @liquidation_order.details['removed_tags'] = @liquidation_order.details['removed_tags'] || []
          @liquidation_order.details['removed_tags'] << liquidations.pluck(:tag_number).flatten
          @liquidation_order.details['items_deleted'] = true
          @liquidation_order.updated_by_id = current_user.id
          liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_competitive_bidding_price)
          update_liquidation(liquidations, liquidation_status)
          if @liquidation_order.save
            @liquidation_order_new = @liquidation_order.dup
            @liquidation_order_new.mrp = @liquidation_order.liquidations.map(&:bench_mark_price).inject(:+)
            @liquidation_order_new.buy_now_price = nil
            @liquidation_order_new.reserve_price = nil
            @liquidation_order_new.floor_price = nil
            @liquidation_order.delete
            if @liquidation_order.liquidations.any?
              @liquidation_order_new.lot_name = @liquidation_order.lot_name.split(' || ').slice(0...-1).join(' || ')
              if @liquidation_order_new.save
                @liquidation_order.liquidations.update_all(lot_name: @liquidation_order_new.lot_name, liquidation_order_id: @liquidation_order_new.id)
              end
            end
          end
        end
        render_success_message("Successfully remove items!", :ok)
      end
    end
  rescue => e
    render_error(e.message, 500)
  end

  private

  def update_liquidation(liquidations, liquidation_status)
    liquidations.each do |liquidation|
      liquidation.is_active = true
      liquidation.liquidation_order_id =  nil
      liquidation.lot_name =  nil
      liquidation.status = liquidation_status.original_code
      liquidation.status_id = liquidation_status.id
      liquidation.details["removed_by_user_id"] = current_user.id
      liquidation.details["removed_by_user_name"] = current_user.full_name
      if liquidation.save
        liquidation.liquidation_request&.add_liquidation
        details = current_user.present? ? { status_changed_by_user_id: current_user.id, status_changed_by_user_name: current_user.full_name } : {}
        LiquidationHistory.create(
          liquidation_id: liquidation.id, status_id: liquidation.status_id, status: liquidation.status,
          created_at: Time.now, updated_at: Time.now, details: details
        )
      end
    end
  end

  def validate_moq_lot_params
    return unless @liquidation_order.is_moq_lot?
    permit_params = [ :possible_sub_lots, {sub_lot_quantity: [:article_id, :article_description, :grade, :lot_quantity]} ]
    permit_params += [ :lot_name, :lot_desc, :start_date, :end_date, :delivery_timeline, :maximum_lots_per_buyer, {lot_range: [:from_lot, :to_lot, :price_per_lot]} ] unless action_name == "remove_lot_items"
    error_message = nil

    permit_params.each do |param|
      if param.is_a?(Hash)
        param.each do |key, value|
          value.each do |val|
            moq_lot_params[key].each do |v|
              error_message = " '#{val} = #{v[val]}'" and break if v[val].blank?
            end
          end
        end
      else
        error_message = " '#{param}'" and break if moq_lot_params.dig(:lot, param).blank? && moq_lot_params[param].blank?
      end
    end

    render_error('Invalid param' + error_message, 422) unless error_message.nil?
  end

  def moq_lot_params
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing)
    sub_lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_sub_lot)
    sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing_sub_lot)
    details = @liquidation_order.details.merge!({'approved_buyer_ids' => params[:approved_buyer_ids], 'sub_lot_quantity' => params[:sub_lot_quantity], 'possible_sub_lots' => params[:possible_sub_lots]})
    @moq_lot_params = {
      lot: {
        lot_name: params[:lot_name],
        lot_desc: params[:lot_desc],
        end_date: params[:end_date],
        start_date: params[:start_date],
        status:lot_status.original_code,
        status_id: lot_status.id,
        lot_type: lot_type.original_code,
        lot_type_id: lot_type.id,
        delivery_timeline: params[:delivery_timeline],
        maximum_lots_per_buyer: params[:maximum_lots_per_buyer],
        details: details,
        created_by_id: current_user.id
      },
      possible_sub_lots: params[:possible_sub_lots],
      sub_lot_quantity: params[:sub_lot_quantity],
      lot_range: params[:lot_range],
      sub_lot_status: sub_lot_status.original_code,
      sub_lot_status_id: sub_lot_status.id,
      sub_lot_type: sub_lot_type.original_code,
      sub_lot_type_id: sub_lot_type.id
    }
  end

  def validate_publish_lot
    @liquidation_orders = LiquidationOrder.where(id: params[:id])
    raise 'Can not publish Republishing lot' and return if @liquidation_orders.pluck(:status).uniq.compact.include?("Ready For Republishing")
  end

  def validate_inventory_grade_mapping
    return unless @liquidation_order.created_by&.bidding_method == "hybrid"
    unless action_name == "remove_lot_items" && !@liquidation_order.is_moq_lot?
      where_qry = params[:sub_lot_quantity].to_a.map do |raw_data|
        "(liquidations.sku_code = '#{raw_data[:article_id]}' AND liquidations.grade = '#{raw_data[:grade]}')"
      end
      where_qry = where_qry.present? ? "(#{where_qry.join(" OR ")})" + " AND liquidations.status = 'MOQ Price'" : {"liquidations.id": @liquidation_order.liquidations.pluck(:id)}
      article_ids = Inventory.validate_grade_mappings(where_qry)
      render_error("Grade mapping not avaibale for selected #{article_ids.join(', ')} items.", 422) if article_ids.any?
    end
  end
end
