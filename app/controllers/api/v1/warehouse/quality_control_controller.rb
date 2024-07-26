class Api::V1::Warehouse::QualityControlController < ApplicationController

  def fetch_inventories
    qc_configuration = QcConfiguration.where(distribution_center_id: distribution_center.try(:id)).first
    inventory_status_warehouse_pending_qc = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_qc).first
    @inventories = Inventory.includes(:inventory_grading_details)
                    .where("inventory_grading_details.is_active = ? and 
                            LOWER(inventories.details ->> 'toat_number') = ? and 
                            inventories.distribution_center_id = ?", 
                            true, params["toat_number"].downcase, qc_configuration.distribution_center_id)
                    .references(:inventory_grading_details)
    to_be_test_count = ((@inventories.count * qc_configuration.sample_percentage) / 100) if qc_configuration.present?
    render json: { inventories: ActiveModel::Serializer::CollectionSerializer.new(@inventories, each_serializer: InventorySerializer), to_be_tested: to_be_test_count }

  end

  def complete_qc
    qc_configuration = QcConfiguration.where(distribution_center_id: distribution_center.try(:id)).first    
    if params[:params][:failure_count].to_i == 0
      @inventories = Inventory.includes(:inventory_grading_details).where("inventory_grading_details.is_active =? and LOWER(inventories.details ->> 'toat_number') = ? and inventories.distribution_center_id = ?", true, params["params"]["toat_number"].downcase, qc_configuration.distribution_center_id).references(:inventory_grading_details)
      @inventories.each do |inventory|
        pick = true
        if inventory.details["disposition"] == "RTV"
          pick = false
          inventory_status_warehouse = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_rtv).first
        elsif inventory.details["disposition"] == "E-Waste"
          inventory_status_warehouse = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_e_waste_compliance_document).first
        elsif inventory.details["disposition"] == "Liquidation"
          inventory_status_warehouse = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_liquidation).first
        elsif inventory.details["disposition"] == "Restock"
          inventory_status_warehouse = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_restock).first
        elsif inventory.details["disposition"] == "Repair"
          inventory_status_warehouse = LookupValue.where(code: Rails.application.credentials.repair_status_repair_initiation).first
          Repair.create(distribution_center_id:distribution_center.try(:id) ,inventory_id: inventory.id ,tag_number: inventory.tag_number,status_id: inventory_status_warehouse.id , is_active:true, details: inventory.details)
        end
        last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
        new_inventory_status = last_inventory_status.dup
        new_inventory_status.status_id = inventory_status_warehouse.try(:id)
        new_inventory_status.is_active = true
        if new_inventory_status.save
          last_inventory_status.update(is_active: false)
          inventory.update(details: inventory.merge_details({"decision" => "Pass", "pick" => pick, "status" => inventory_status_warehouse.try(:original_code)}))
          VendorReturn.create_record(inventory) if inventory.details["disposition"] == "RTV"
        end
      end      
    else
      @inventories.each do |inventory|
        inventory.update_details({"decision" => "Fail"})
      end
    end
    render json: @inventories
  end

end