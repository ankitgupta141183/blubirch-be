class InventoryInformation < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory

  def self.create_inventory_histories(date  = Date.today)
    inventories = Inventory.includes(:inventory_information, :vendor_return, :repair, :replacement, :liquidation, :insurance, :markdown, :redeploy).where("is_forward = ? and updated_at >= ?", false, date)
    
    inventory_status_closed = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
    inventories.each do |inv|
    	disposition_obj = {}
      inv_obj = {distribution_center_id: inv.distribution_center_id, client_id: inv.client_id, user_id: inv.user_id,
                 tag_number: inv.tag_number, details: inv.details, deleted_at: inv.deleted_at, gate_pass_id: inv.gate_pass_id,
                 sku_code: inv.sku_code, item_description: inv.item_description, quantity: inv.quantity, 
                 client_tag_number: inv.client_tag_number, disposition: inv.disposition, grade: inv.grade, serial_number: inv.serial_number,
                 toat_number: inv.toat_number, return_reason: inv.return_reason, aisle_location: inv.aisle_location, 
                 item_price: inv.item_price, gate_pass_inventory_id: inv.gate_pass_inventory_id, sr_number: inv.sr_number, 
                 serial_number_2: inv.serial_number_2, status_id: inv.status_id, status: inv.status, client_category_id: inv.client_category_id,
                 item_inward_date: inv.created_at}
      if inv.vendor_return.present?
        vendor_return_obj = inv.try(:vendor_return)
        disposition_obj.deep_merge!({vendor_return_id: vendor_return_obj.try(:id), vendor_return_status: vendor_return_obj.status,
                                     vendor_return_created_at: vendor_return_obj.created_at, vendor_return_updated_at: vendor_return_obj.updated_at})
      end
      if inv.repair.present?
        repair_obj = inv.try(:repair)
        disposition_obj.deep_merge!({repair_id: repair_obj.try(:id), repair_status: repair_obj.status,
                                     repair_created_at: repair_obj.created_at, repair_updated_at: repair_obj.updated_at})
      end
      if inv.replacement.present?
        replacement_obj = inv.try(:replacement)
        disposition_obj.deep_merge!({replacement_id: replacement_obj.try(:id), replacement_status: replacement_obj.status,
                                     replacement_created_at: replacement_obj.created_at, replacement_updated_at: replacement_obj.updated_at})
      end
      if inv.insurance.present?
        insurance_obj = inv.try(:insurance)
        disposition_obj.deep_merge!({insurance_id: insurance_obj.try(:id), insurance_status: insurance_obj.status,
                                     insurance_created_at: insurance_obj.created_at, insurance_updated_at: insurance_obj.updated_at})
      end
      if inv.markdown.present?
        markdown_obj = inv.try(:markdown)
        disposition_obj.deep_merge!({markdown_id: markdown_obj.try(:id), markdown_status: markdown_obj.status,
                                     markdown_created_at: markdown_obj.created_at, markdown_updated_at: markdown_obj.updated_at})
      end
      if inv.redeploy.present?
        redeploy_obj = inv.try(:redeploy)
        disposition_obj.deep_merge!({redeploy_id: redeploy_obj.try(:id), redeploy_status: redeploy_obj.status,
                                     redeploy_created_at: redeploy_obj.created_at, redeploy_updated_at: redeploy_obj.updated_at})
      end
      if inv.liquidation.present?
        liquidation_obj = inv.try(:liquidation)
        disposition_obj.deep_merge!({liquidation_id: liquidation_obj.try(:id), liquidation_status: liquidation_obj.status,
                                     liquidation_created_at: liquidation_obj.created_at, liquidation_updated_at: liquidation_obj.updated_at})
      end
      if inv.status_id == inventory_status_closed.id
        disposition_obj.deep_merge!({disptach_date: inv.try(:inventory_statuses).try(:last).try(:created_at)})
      end
      
      if disposition_obj.present?   
        final_obj = inv_obj.deep_merge!(disposition_obj)
      else
        final_obj = inv_obj
      end
      if inv.inventory_information.present?
        inv.inventory_information.update(final_obj)
      else
        self.create(final_obj.merge({inventory_id: inv.id}))
      end
    end
  end

end
