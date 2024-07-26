class DispositionRule < ApplicationRecord
  acts_as_paranoid
  belongs_to :rule
  belongs_to :category

  def self.create_bucket_record(disposition, inventory, path=nil, user_id=nil)
    bucket_status = nil
    case disposition
    when LookupValue.where(code: Rails.application.credentials.warehouse_disposition_brand_call_log).first.try(:original_code)
      BrandCallLog.create_record(inventory, user_id)
      bucket_status = LookupValue.find_by(code: "brand_call_log_status_pending_information")
    when LookupValue.where(code: Rails.application.credentials.warehouse_disposition_insurance).first.try(:original_code)
      Insurance.create_record(inventory, user_id)
      bucket_status = LookupValue.find_by(code: "insurance_status_pending_information")
    when LookupValue.where(code: Rails.application.credentials.warehouse_disposition_replacement).first.try(:original_code)
      Replacement.create_record(inventory, user_id)
    when LookupValue.where(code: Rails.application.credentials.warehouse_disposition_pending_disposition).first.try(:original_code)
      PendingDisposition.create_record(inventory, user_id)
    when "Repair"
      Repair.create_record(inventory, user_id)
      bucket_status = LookupValue.where("code = ?", Rails.application.credentials.repair_status_pending_repair_quotation).first
    when "Liquidation"
      Liquidation.create_record(inventory, path, user_id)
    when "Redeploy"
      Redeploy.create_record(inventory, user_id)
      bucket_status = LookupValue.where("code = ?", Rails.application.credentials.redeploy_status_pending_redeploy_destination).first
    when "Pending Transfer Out", "Markdown"
      Markdown.create_record(inventory, user_id)
    when "E-Waste"
      EWaste.create_record(inventory, user_id)
    when "RTV"
      VendorReturn.create_rtv_record(inventory, user_id)
    when "Cannibalization"
      Cannibalization.create_cannibalize_record(inventory, user_id)
    when "Restock"
      Restock.create_record(inventory, user_id)
      bucket_status = LookupValue.where("code = ?", Rails.application.credentials.restock_status_pending_restock_destination).first
    end

    # Create Inventory Status
    # disposition = inventory.disposition if inventory.disposition.present?
    if disposition == "E-Waste"
      bucket_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_e_waste).first
    elsif bucket_status.blank?
      code = 'inventory_status_warehouse_pending_'+ disposition.try(:downcase).try(:parameterize).try(:underscore)
      bucket_status =  LookupValue.find_by_code(Rails.application.credentials.send(code))
    end
    inventory.status = bucket_status.original_code
    inventory.status_id = bucket_status.id
    inventory.details["issue_type"] = nil
    if inventory.save(:validate => false)
      existing_inventory_status = inventory.inventory_statuses.where(is_active: true).last
      inventory_status = existing_inventory_status.present? ? existing_inventory_status.dup : inventory.inventory_statuses.new
      inventory_status.status = bucket_status
      inventory_status.is_active = true
      existing_inventory_status.update_attributes(is_active: false) if existing_inventory_status.present?
      inventory_status.save
    end
  end
  
  def self.create_fwd_bucket_record(disposition, forward_inv, path = nil, user_id = nil)
    case disposition
    when "Replacement"
      ForwardReplacement.create_record(forward_inv, user_id)
    when "Saleable"
      Saleable.create_record(forward_inv, user_id)
    when "Demo"
      Demo.create_record(forward_inv, user_id)
    when "Rental"
      Rental.create_record(forward_inv, user_id)
    when "Capital Assets"
      CapitalAsset.create_record(forward_inv, user_id)
    when "Production"
      Production.create_record(forward_inv, user_id)
    else
      raise "#{disposition} disposition is under development!" and return
    end
    # Please Note: Update the forward_inventory status and disposition in the respective bucket model after disposition. Refer ForwardReplacement model
  end


  def self.update_bucket_records_for_active
    VendorReturn.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "RTV") || (vr.try(:inventory).try(:disposition) == "Brand Call-Log")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Repair.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Repair")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Replacement.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Replacement")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Markdown.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Pending Transfer Out")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Liquidation.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Liquidation")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Redeploy.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Redeploy")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    Restock.all.each do |vr|
      is_active = vr.try(:inventory).try(:disposition) == "Restock"
      vr.update(is_active: is_active)
    end

    Insurance.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "Insurance")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end

    EWaste.all.each do |vr|
      if (vr.try(:inventory).try(:disposition) == "E-Waste")
        vr.update(is_active: true)
      else
        vr.update(is_active: false)
      end
    end
  end

  def self.update_is_active_for_closed_bucket
    # Vendor Return
    vr_closed_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_rtv_closed)
    vendor_returns = VendorReturn.where(status: vr_closed_status.original_code)
    vendor_returns.update_all(is_active: false) if vendor_returns.present?

    # Insurance
    insurance_status_closed = LookupValue.find_by_code(Rails.application.credentials.insurance_status_insurance_closed)
    insurances = Insurance.where(status: insurance_status_closed.original_code)
    insurances.update_all(is_active: false) if insurances.present?

    # Replacement
    replacement_closed_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_replacement_closed)
    replacements = Replacement.where(status: replacement_closed_status.original_code)
    replacements.update_all(is_active: false) if replacements.present?
  end

  def self.sync_policy_key_name
    Liquidation.all.each do |l|
      if l.details['policy_name'].present?
        l.details['policy_type'] = l.details['policy_name']
        l.save
      end
      if l.inventory.details['policy_name'].present?
        i = l.inventory
        i.details['policy_type'] = i.details['policy_name']
        i.save
      end
    end
  end

  def self.update_existing_repair_and_redeploy_bucket
    # Update Repair
    pds = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition_set).original_code
    repairs = Repair.where(status: pds)
    repairs.update_all(is_active: false) if repairs.present?

    # Repair update
    redeploy_status = LookupValue.find_by(code: Rails.application.credentials.redeploy_status_redeploy_dispatch_complete)
    redeployes = Redeploy.where(status: redeploy_status.original_code)
    redeployes.update_all(is_active: false) if redeployes.present?
  end
end