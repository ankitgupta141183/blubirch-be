# frozen_string_literal: true

class ForwardInventory < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :client_category, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :sub_location, optional: true
  belongs_to :vendor, class_name: 'VendorMaster', optional: true
  belongs_to :forward_inventory_status, class_name: 'LookupValue', foreign_key: :status_id
  belongs_to :pending_receipt_document_item, optional: true

  has_many :forward_inventory_statuses
  has_many :forward_replacements

  validates :tag_number, length: { minimum: 5 }
  
  STATUS_LOOKUP_KEY_NAMES = {"Rental" => "RENTAL_STATUS", "Saleable" => "SALEABLE_STATUS", "Capital Assets" => "CAPITAL_ASSET_STATUS", "Demo" => "FORWARD_DEMO_STATUS", "Production" => "PRODUCTION_STATUS"}

  def update_inventory_status(bucket_status, current_user_id = nil)
    existing_inventory_status = forward_inventory_statuses.where(is_active: true).last
    inventory_status = existing_inventory_status.present? ? existing_inventory_status.dup : forward_inventory_statuses.new
    inventory_status.status = bucket_status
    inventory_status.distribution_center_id = distribution_center_id
    inventory_status.is_active = true
    inventory_status.user_id = current_user_id
    inventory_status.details = {}
    inventory_status.save!

    existing_inventory_status.update(is_active: false) if existing_inventory_status.present?
    update(status: bucket_status.original_code, status_id: bucket_status.id)
  end

  def get_current_bucket
    frwd_inv = self
    case frwd_inv.disposition
    when 'Saleable'
      bucket_record = Saleable.where(inventory_id: frwd_inv.id)
    when 'Production'
      raise 'Module is not implemented'
    when 'Usage'
      raise 'Module is not implemented'
    when 'Demo'
      bucket_record = Demo.where(forward_inventory_id: frwd_inv.id)
    when 'Replacement'
      bucket_record = ForwardReplacement.where(forward_inventory_id: frwd_inv.id)
    when 'Capital Assets'
      bucket_record = CapitalAsset.where(inventory_id: frwd_inv.id)
    when 'Rental'
      bucket_record = Rental.where(inventory_id: frwd_inv.id)
    when "Dispatch"
      bucket_record = WarehouseOrderItem.where(forward_inventory_id: frwd_inv.id)
    else
      raise 'No Bucket found for forward Inventory'
    end
    bucket_record.order("updated_at").last
  end
end
