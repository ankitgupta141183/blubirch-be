# frozen_string_literal: true

class TransferInventory < ApplicationRecord
  belongs_to :inventoryable, polymorphic: true
  belongs_to :transfer_order, optional: true
  belongs_to :sub_location, optional: true
  belongs_to :distribution_center, optional: true
  belongs_to :vendor_master

  def self.create_record(inventoryable, _current_user)
    status = LookupValue.find_by(code: 'transfer_inventory_status_pending_transfer')
    ActiveRecord::Base.transaction do
      record                        = new
      record.inventoryable          = inventoryable
      record.article_id             = inventoryable.sku_code
      record.article_description    = inventoryable.item_description
      record.tag_number             = inventoryable.tag_number
      record.details                = inventoryable.details
      record.client_category_id     = inventoryable.client_category_id
      record.distribution_center_id = inventoryable.distribution_center_id
      record.receving_location_id   = inventoryable.details['destination_id']
      record.remarks                = inventoryable.details['remarks']
      record.vendor_master_id       = inventoryable.details['transfer_vendor_id']
      record.transfer_date          = Date.today
      record.status_id              = status&.id
      record.status                 = status&.original_code
      record.save!
      record
    end
  end
end
