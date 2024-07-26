class VendorReturnHistory < ApplicationRecord
  acts_as_paranoid
  belongs_to :vendor_return
  belongs_to :status, class_name: 'LookupValue', foreign_key: "status_id"

  def self.update_existing_rtv_records
    VendorReturn.all.each do |vendor_return|
      inventory = vendor_return.inventory
      vrs = VendorReturn.where(inventory_id: inventory.id, is_active: true)
      if vrs.count > 1
        vrs.where.not(id: vrs.last.id).delete_all
      end
    end

    Inventory.all.each do |inventory|
      vendor_returns = VendorReturn.where(inventory_id: inventory.id)
      active_vr = vendor_returns.where(is_active: true).last
      vendor_returns.each do |vendor_return|
        vrh = VendorReturnHistory.new(vendor_return_id: active_vr.id, status_id: vendor_return.status_id)
        vrh.details = {}
        vrh.details['pending_call_logs_created_at'] = vendor_return.created_at if vendor_return.status.original_code == 'Pending Call logs'
        vrh.details['pending_brand_approval_created_at'] = vendor_return.created_at if vendor_return.status.original_code == 'Pending Brand Approval'
        vrh.details['pending_dispatch_created_at'] = vendor_return.created_at if vendor_return.status.original_code == 'Pending Dispatch'
        vrh.details['pending_disposition_created_at'] = vendor_return.created_at if vendor_return.status.original_code == 'Pending Disposition'
        vrh.save
      end
      vendor_returns.where(is_active: false).delete_all
    end
  end
end
