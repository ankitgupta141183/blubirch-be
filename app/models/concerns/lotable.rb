# frozen_string_literal: true
module Lotable
  extend ActiveSupport::Concern

  module ClassMethods

    def create_lot(lot_params, current_user)
      original_code, status_id = LookupStatusService.new('Liquidation', 'create_beam_lots').call
      liquidation_order = LiquidationOrder.new(lot_params[:lot])
      if liquidation_order.save!
        if lot_params[:liquidation_ids].present?
          liquidation_history_arr = []
          liquidations = Liquidation.includes(:liquidation_request).where(id: lot_params[:liquidation_ids])
          lot = liquidation_order.is_moq_sub_lot? ? lot_params[:parent_lot] : liquidation_order
          liquidations.update_all(
            lot_name: lot.lot_name,
            liquidation_order_id: lot.id,
            status: original_code,
            status_id: status_id,
            lot_type: lot.lot_type,
          )
          liquidations.each { |liquidation| liquidation_history_arr << liquidation.post_lot_creation_cleanup(current_user) }
          liquidation_order.assign_lot_category(liquidations) unless liquidation_order.lot_category.present?
          liquidation_order.update_tags(liquidations) unless liquidation_order.tags.present?
          LiquidationHistory.import(liquidation_history_arr) if liquidation_history_arr.present?
        end
        liquidation_order.liquidation_order_histories.create(status: liquidation_order.status, status_id: liquidation_order.status_id)
        liquidation_order.update_lot_images lot_params
      end
      liquidation_order
    end

    # TODO
    def publish_lot

    end

    # TODO
    def republish_lot

    end

    def delete_los(ids, current_user)
      lots = self.where(id: ids)
      lot_ids = {successfull_deleted_ids: [], amount_received_ids: [], bids_present_ids: []}
      lots.each do |lot|
        status_type = if lot.is_moq_lot? || lot.is_moq_sub_lot?
          'liquidation_status_moq_price'
        elsif lot.is_b2c?
          'liquidation_status_pending_b2c_publish'
        else
          'liquidation_status_competitive_bidding_price'
        end
        liquidation_status = LookupValue.find_by(code: Rails.application.credentials.send(status_type))
        if lot.is_moq_lot?
          deleted_sub_lots = []
          deleted_sub_lots = lot.moq_sub_lots.joins("LEFT OUTER JOIN liquidations ON liquidations.liquidation_order_id = liquidation_orders.id").where("liquidations.deleted_at IS NULL AND liquidations.id IS NULL").pluck(:id)
          options = {sub_lot_ids: deleted_sub_lots, user_id: current_user.id, liquidation_status_id: liquidation_status.id, liquidation_order_id: lot.id}
          LiquidationOrderWorker.perform_async(options)
          lot.details['deleted_sub_lots'] = deleted_sub_lots
          lot.save
        elsif lot.amount_received.to_i > 0
          lot_ids[:amount_received_ids] << lot.id
          next
        elsif lot.bids.present? && lot.status == "In Progress B2B"
          lot_ids[:bids_present_ids] << lot.id
          next
        end

        lot.delete_lot(liquidation_status, current_user)
        lot_ids[:successfull_deleted_ids] << lot.id
      end
      lot_ids
    end
  end

  def publish(current_user)
    case current_user.bidding_method
    when 'hybrid'
      response = self.publish_to_reseller(current_user)
      check_if_lot_published response, "Reseller"
    when "open"
      response = self.publish_to_beam(current_user)
      check_if_lot_published response, "SCB"
    when "blind"
      # TODO
    end
  end

  def publish_b2c(current_user)
    case self.platform
    when "beam"
      response = self.publish_to_beam(current_user)
      check_if_lot_published response, "SCB"
    when "amazon"
      # TODO
    when "flipkart"
      # TODO
    end
  end

  def update_lot lot_params, user
    if lot_params.present? && update(lot_params[:lot])
      update_lot_images lot_params
      move_to_ready_for_publishing
    end
    return self if lot_params[:liquidations].blank?

    create_new_lot_with_updated_tag_ids lot_params[:liquidations], user
  end

  def update_lot_images lot_params
    add_new_images lot_params[:images]
    remove_lot_attachments lot_params[:removed_urls]
    image_urls = lot_params[:image_urls] || lot_params[:lot][:lot_image_urls]
    add_inventory_images_to_lot image_urls
    self.lot_image_urls = [] if image_urls.blank?
    self.lot_attachments.reload
    lot_images = (self.lot_image_urls += self.lot_attachments.map(&:attachment_file_url)).flatten.compact.uniq
    update(lot_image_urls: lot_images)
  end

  def delete_lot(liquidation_status, current_user)
    options = {liquidation_ids: liquidations.pluck(:id), user_id: current_user.id, liquidation_status_id: liquidation_status.id, liquidation_order_id: self.id}
    LiquidationOrderWorker.perform_async(options)
    remove_lots_from_reseller(self.beam_lot_id) if self.beam_lot_id && !self.is_moq_sub_lot?
    self.destroy
  end

  def assign_lot_category(liquidations)
    lot_category = liquidations.joins(:client_category).includes(:client_category).map{ |l| l.client_category.path.pluck(:name).first }.compact.uniq.join(' || ') rescue "N/A"
    self.update_columns(lot_category: lot_category)
  end

  def update_moq_lot_quantity(sub_quantity, lot_remove = false)
    details['sub_lot_quantity'].each do |sub_lot|
      if lot_remove
        sub_lot['quantity'] =  sub_lot['quantity'].to_i - (sub_lot['lot_quantity'].to_i * sub_quantity)
      else
        sub_lot['quantity'] =  sub_lot['quantity'].to_i + (sub_lot['lot_quantity'].to_i * sub_quantity)
      end
    end
    self.save
  end

  private

    def add_new_images images
      return if images.blank?
      images.each do |file|
        lot_attachment = lot_attachments.new(attachment_file: file)
        lot_attachment.save!
      end
    end

    def remove_lot_attachments removed_urls
      return if removed_urls.blank?

      self.lot_image_urls = [] if self.lot_image_urls.blank?
      lot_images = (self.lot_image_urls - removed_urls).flatten.compact.uniq
      update(lot_image_urls: lot_images)
      lot_attachments.each do |attachment|
        attachment.destroy if removed_urls.include?(attachment.attachment_file_url)
      end
    end

    def add_inventory_images_to_lot inv_img_urls
      return if inv_img_urls.blank?

      self.lot_image_urls = [] if self.lot_image_urls.blank?
      lot_images = (self.lot_image_urls += inv_img_urls).flatten.compact.uniq
      update(lot_image_urls: lot_images)
    end

    def check_if_lot_published response, client
      if response.code != 200
        Rails.logger.error("Lot publish on #{client} got failed")
        Rails.logger.info(response.body)
        response_body = JSON.parse(response.body)
        errors = response_body['error'].presence || response_body['errors'].presence
        errors.is_a?(Array) ? errors.join(',') : errors
      end
    end

    def move_to_ready_for_publishing
      pending_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_lot_details)
      lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing)
      if status_id == pending_lot_status.id
        update(status: lot_status.original_code, status_id: lot_status.id)
      end
    end

    def create_new_lot_with_updated_tag_ids lot_params, user
      deleted_liquidations = Liquidation.where(tag_number: lot_params[:tag_numbers])
      if deleted_liquidations.present?
        update_old_lot_details deleted_liquidations, lot_params, user
        liquidation_order_new = create_new_lot_from_old_lot lot_params
        order_items = WarehouseOrderItem.where(tag_number: tags)
        delete_order_items order_items, lot_params, user if order_items.present?
        liquidation_order_new
      end
    end

    def create_new_lot_from_old_lot lot_params
      old_lot_name = self.lot_name
      liquidation_order_new = self.dup
      liquidation_order_new.lot_name = nil
      liquidation_order_new.quantity = quantity - liquidations.size
      move_all_liquidations_to_new_lot liquidation_order_new if liquidation_order_new.save!
      liquidation_order_new.update(lot_name: old_lot_name)
      liquidation_order_new
    end

    def move_all_liquidations_to_new_lot lot
      self.liquidations.update_all(liquidation_order_id: lot.id)
      self.delete
    end

    def update_old_lot_details deleted_liquidations, lot_params, user
      deleted_tags = deleted_liquidations.pluck(:tag_number).flatten
      details['removed_tags'] = details['removed_tags'] || []
      details['removed_tags'] << deleted_tags
      details['items_deleted'] = true
      self.tags = self.tags - deleted_tags

      liquidation_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_competitive_bidding_price)

      # unassign the deleted lots from the lot
      deleted_liquidations.map { |liquidation| liquidation.release_from_current_lot(user, liquidation_status, lot_params)}
      self.save
    end

    def delete_order_items order_items, lot_params, user
      if order_items.present?
        order_items.each do |item|
          if item.warehouse_order.present?
            order = item.warehouse_order
            order.total_quantity = order.total_quantity - 1
            order.save
            order.delete if order.total_quantity == 0
          end

          item_details = {
            reason_for_not_dispatch: lot_params["reason"],
            remark_for_not_dispatch: lot_params["remark"],
            removed_by_user_id: user.id,
            removed_by_user_name: user.full_name,
          }
          item.details.merge(item_details)
          item.save
          item.delete
        end
      end
    end

    def remove_lots_from_reseller(beam_id)
      url = Rails.application.credentials.reseller_url+"/api/lot_publishes/#{beam_id}/cancel_lot"
      RestClient::Request.execute(method: :post, url: url, payload: {username: AccountSetting.first&.username, deleted_sub_lots: details['deleted_sub_lots']}, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    end
end
