# frozen_string_literal: true

class Demo < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :forward_inventory
  belongs_to :client_sku_master, optional: true

  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }

  def self.create_record(forward_inventory, user_id)
    status = LookupValue.find_by(code: 'forward_demo_status_demo')
    disposition = LookupValue.find_by(code: 'forward_disposition_demo')
    ActiveRecord::Base.transaction do
      record                        = new
      record.forward_inventory      = forward_inventory
      record.distribution_center_id = forward_inventory.distribution_center_id
      record.client_sku_master_id   = forward_inventory.client_sku_master_id
      record.tag_number             = forward_inventory.tag_number
      record.sku_code               = forward_inventory.sku_code
      record.item_description       = forward_inventory.item_description
      record.serial_number          = forward_inventory.serial_number
      record.supplier               = forward_inventory.supplier
      record.grade                  = forward_inventory.grade
      record.details                = forward_inventory.details
      record.status_id              = status.id
      record.status                 = status.original_code
      record.item_price             = forward_inventory.item_price
      record.quantity               = forward_inventory.quantity
      record.is_active              = true
      record.save!

      forward_inventory.update!(disposition: disposition.original_code, disposition_id: disposition.id)
      record.update_inventory_status(status, user_id)
    end
  end

  def update_inventory_status(status, user_id)
    fwd_inv = forward_inventory
    raise CustomErrors, 'Invalid Status' if status.blank?

    fwd_inv.update_inventory_status(status, user_id)
  end

  def set_disposition(disposition, current_user = nil)
    raise CustomErrors, "Disposition can't be blank!" if disposition.blank?

    self.is_active = false
    save!

    DispositionRule.create_fwd_bucket_record(disposition, forward_inventory, 'Demo', current_user&.id)
  end
end
