class RepublishWorker
  include Sidekiq::Worker

  def perform(params)
    params = params.with_indifferent_access
    old_liquidation_order = LiquidationOrder.includes(:liquidations).find_by(id: params[:id])
    begin
      if params[:bidding_method] == "hybrid"
        if old_liquidation_order.is_moq_lot?
          old_liquidation_order.assign_attributes(params[:lot])
          if old_liquidation_order.valid?
            old_liquidation_order.republish_status = 'republishing'
            old_liquidation_order.save!
            old_liquidation_order.moq_sub_lot_prices.delete_all
            old_liquidation_order.moq_sub_lot_prices.create!(params[:lot_range].map{|lot_range| {from_lot: lot_range[:from_lot], to_lot: lot_range[:to_lot], price_per_lot: lot_range[:price_per_lot]}})
            params[:lot].merge!({ status: params[:sub_lot_status], status_id: params[:sub_lot_status_id], lot_type: params[:sub_lot_type], lot_type_id: params[:sub_lot_type_id] })
            old_liquidation_order.moq_sub_lots.where(status: "MOQ Sub Lot Pending Decision").each do |moq_sub_lot|
              lot_name = params[:lot][:lot_name].to_s + " || #{moq_sub_lot.id}-#{moq_sub_lot.lot_order}"
              moq_sub_lot.update!(params[:lot].merge({lot_name: lot_name}))
            end
          else
            raise ActiveRecord::Rollback
          end
        else
          lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_competitive_lot)
          lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_republishing)

          old_liquidation_order.assign_attributes(
            lot_name: params[:lot_name],
            lot_desc: params[:lot_desc],
            mrp: params[:lot_mrp],
            end_date: params[:end_date],
            start_date: params[:start_date],
            status: lot_status.original_code,
            status_id: lot_status.id,
            order_amount: params[:lot_expected_price],
            lot_type: lot_type.original_code,
            lot_type_id: lot_type.id,
            floor_price: params[:floor_price].to_f,
            reserve_price: params[:reserve_price].to_f,
            buy_now_price: params[:buy_now_price].to_f,
            increment_slab: params[:increment_slab].to_i,
            liquidation_order_id: old_liquidation_order.parent_liquidation_order_id,
            details: old_liquidation_order.details.merge({ 'approved_buyer_ids' => params[:approved_buyer_ids], 'old_beam_lot_id' => old_liquidation_order.beam_lot_id }),
            beam_lot_id: nil,
            delivery_timeline: params[:delivery_timeline],
            additional_info: params[:additional_info],
            bid_value_multiple_of: params[:bid_value_multiple_of]
          )
          if old_liquidation_order.valid?
            old_liquidation_order.lot_attachments.delete_all
            if params[:images].present?
              params[:images].each do |file|
                lot_attachment = old_liquidation_order.lot_attachments.new(attachment_file: file)
                lot_attachment.save!
              end
            end
            old_liquidation_order.lot_attachments.reload
            lot_attachments = old_liquidation_order.lot_attachments
            old_liquidation_order.lot_image_urls = params[:image_urls] || []
            old_liquidation_order.lot_image_urls += lot_attachments.map(&:attachment_file_url)
            old_liquidation_order.republish_status = 'republishing'
            old_liquidation_order.save!
          else
            raise ActiveRecord::Rollback
          end
        end
      else
        lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
        lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_in_progress_b2b)
        lot_attachments = LotAttachment.where(id: params[:lot_attachment_ids])
        liquidation_items = old_liquidation_order.liquidations
        liquidation_order = LiquidationOrder.new(lot_name: params[:lot_name], lot_desc: params[:lot_desc], mrp: params[:lot_mrp], end_date: params[:end_date], start_date: params[:start_date], status: lot_status.original_code, status_id: lot_status.id, order_amount: params[:lot_expected_price], quantity: liquidation_items.count, lot_type: lot_type.original_code, lot_type_id: lot_type.id, floor_price: params[:floor_price].to_f, reserve_price: params[:reserve_price].to_f, buy_now_price: params[:buy_now_price].to_f, increment_slab: params[:increment_slab].to_i, lot_image_urls: JSON.parse(params[:images]))
        liquidation_order.lot_image_urls += lot_attachments.map(&:attachment_file_url)
        if liquidation_order.valid?
          response = liquidation_order.republish_to_beam_async(old_liquidation_order.lot_name, params)
          raise ActiveRecord::Rollback if response.code != 200
        else
          raise ActiveRecord::Rollback
        end
      end
    rescue => e
      #lot_attachments&.delete_all 
      old_liquidation_order.update(republish_status: "error")
      Rails.logger.error("Error occured while republish")
    end
  end  
end
