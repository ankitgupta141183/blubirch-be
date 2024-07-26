# frozen_string_literal: true

# issueInventory modules no doc
class IssueInventory < ApplicationRecord
  default_scope { where(deleted_at: nil) }
  enum inventory_status: { short: 0, excess: 1 }
  enum status: { pending_for_action: 0, pending_for_approval: 1, approved: 2 }
  enum current_status: { write_off: 0, write_on: 1, currect_excess: 2 }
  belongs_to :physical_inspection
  belongs_to :distribution_center
  belongs_to :inventory

  before_save :move_inventories, if: :approved_status_changed?

  attr_accessor :current_user

  def approved_status_changed?
    status_changed? && status == 'approved'
  end

  def move_inventories
    if write_off?
      create_order_management_system('reverse', 'outward_return_order')
      move_to_3p_claim
    elsif write_on?
      create_order_management_system('forward', 'purchase_order')
      move_to_inward
    elsif currect_excess?
      correct_excess_location
    end

    self.deleted_at = Time.zone.now
  end

  def correct_excess_location
    sub_location = SubLocation.includes(:distribution_center).find_by(id: details["sub_location_id"]) if details.present? && details["sub_location_id"].present?
    sub_location_id, distribution_center_id = if sub_location.present? && sub_location.distribution_center.present?
      [ sub_location.id, sub_location.distribution_center.id ]
    else
      [nil, self.distribution_center_id]
    end
    update_attrs = { distribution_center_id: distribution_center_id, is_putaway_inwarded: false }
    update_attrs[:sub_location_id] = sub_location_id if sub_location_id.present?
    update!(distribution_center_id: distribution_center_id)
    inventory.update!(update_attrs)
    inventory.update_all_associated_destribution_id(distribution_center_id)
  end

  def move_to_3p_claim
    if details.present? && details['vendor_code'].present?
      hash = details.except('name')
      hash.merge!({ inventory_id: inventory_id, note_type: :debit, cost_type: :write_off, stage_name: :debit_note_against_vendors, tab_status: :recovery })
      ThirdPartyClaim.create_thrid_party_claim([hash])
    else
      inventory.outward_inventory!(current_user)
    end
  end

  def move_to_inward
    item = Item.find_or_initialize_by(tag_number: inventory.tag_number)
    # NOTE: this is only for old invetory, as old inventories tag numbet will not present in item, and for inwarding we need item tables
    if item.new_record?
      item.assign_attributes(sku_code: inventory.sku_code, sku_description: inventory.item_description, return_reason: inventory.return_reason, client_category_name: inventory.client_category&.name,
                             user_id: inventory.user_id, client_id: inventory.client_id, details: inventory.details)
    end
    key = LookupKey.find_by(code: 'INWARD_STATUSES')
    value = key.lookup_values.find_by(code: 'inward_statuses_pending_item_inwarding')
    item.status = value.original_code
    item.status_id = value.id
    item.save(validate: false)
  end

  def create_order_management_system(oms_type, order_type)
    order_params = {billing_location_id: distribution_center.id, receiving_location_id: distribution_center.id, order_reason: "Creating from physical inspection", items: [{sku_code: inventory.sku_code, price: inventory.item_price, quantity: inventory.quantity, total_price: inventory.item_price * inventory.quantity, item_description: inventory.item_description}]}
    vendor = ClientProcurementVendor.find_by(vendor_code: details['vendor_code']) if details&.dig('vendor_code').present?
    order_params.merge!({ vendor_id: vendor.id }) if vendor.present?
    OrderManagementSystem.create_order(oms_type: oms_type, order_type: order_type, order_params: order_params)
  end

  def show_correct_access
    (distribution_center_id != inventory.distribution_center_id) || (inventory.distribution_center.sub_locations.pluck(:id).exclude?(inventory.sub_location_id))
  end
end
