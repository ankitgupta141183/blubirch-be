class Api::V1::Warehouse::InventoriesController < ApplicationController

  def item_info
    if params['tag_number'].present?
      @item_info = Inventory.where("tag_number = ? OR serial_number = ?", params['tag_number'], params['tag_number']).last
      render json: @item_info, serializer: Api::V1::Warehouse::ItemInfoSerializer if @item_info.present?
      render json: {message: "Not Found", status: 302} if @item_info.blank?
    else
      render json: {message: "Please provide valid tag number", status: 204}
    end
  end


  def search_inventory
    if params['tag_number'].present?
      @inventory = Inventory.where("tag_number = ? OR serial_number = ?", params['tag_number'], params['tag_number']).last
      if @inventory.blank?
        render json: {message: "Not Found", status: 302}
      else
        render json: @inventory
      end
    else
      render json: {message: "Please provide valid tag number", status: 204}
    end
  end

  def search_items
    search_param = params['search'].split(',').collect(&:strip).flatten
    if params['search_in'] == 'brand'
      @inventories = Inventory.where("lower(details ->> 'brand') IN (?) ", search_param.map(&:downcase))
    else
      @inventories = Inventory.where("lower(#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    end
    render json: @inventories
  end

  def update_serial_number
    @inventory = Inventory.find_by_tag_number(params['tag_number'])
    if @inventory.present?
      @inventory.serial_number = params['serial_number'] if params['serial_number'].present?
      @inventory.serial_number_2 = params['serial_number_2'] if params['serial_number_2'].present?
      @inventory.sr_number = params['sr_number'] if params['sr_number'].present?
      if params['invoice_number'].present?
        @inventory.details['invoice_number'] = params['invoice_number']
        file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
        invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
        doc = @inventory.inventory_documents.where(document_name_id: invoice_file_type.id).last
        if doc.present?
          doc.update(reference_number: params['invoice_number'])
        end
      end
      if params['call_log_number'].present?
        call_log_number = params['call_log_number'].gsub(/[^0-9A-Za-z\\-]/, '')
        vr = VendorReturn.where(tag_number: @inventory.tag_number)
        vr.update_all(call_log_id: call_log_number) if vr.present?
        ins = Insurance.where(tag_number: @inventory.tag_number)
        ins.update_all(call_log_id: call_log_number) if ins.present?
        rep = Replacement.where(tag_number: @inventory.tag_number)
        rep.update_all(call_log_id: call_log_number) if rep.present?
      end
      @inventory.details['details_updated_by_username'] = current_user.username
      @inventory.details['details_updated_by_user_id'] = current_user.id
      if @inventory.save
        bucket = @inventory.get_current_bucket
        bucket.update_attributes(sr_number: @inventory.sr_number, serial_number: @inventory.serial_number, serial_number_2: @inventory.serial_number_2) if (bucket.present? && bucket.class.name != 'VendorReturn')
        bucket.update_attributes(sr_number: @inventory.sr_number, serial_number: @inventory.serial_number, serial_number2: @inventory.serial_number_2) if (bucket.present? && bucket.class.name == 'VendorReturn')
      end

      render json: @inventory
    else
      render json: {message: "Please provide valid tag number", status: 204}
    end
  end

  def document_search
    if params['reference_number'].present?
      @warehouse_order_document = WarehouseOrderDocument.where("lower(reference_number) = ? AND attachable_type != ?", params['reference_number'].downcase, 'WarehouseConsignment').last
      @warehouse_order_document = WarehouseOrder.where("lower(outward_invoice_number) = ?", params['reference_number'].downcase).last if @warehouse_order_document.blank?
      @warehouse_order_document = InventoryDocument.where("lower(reference_number) = ?", params['reference_number'].downcase).last if @warehouse_order_document.blank?
      render json: @warehouse_order_document, serializer: Api::V1::Warehouse::WarehouseOrderDocumentSerializer if @warehouse_order_document.present?
      render json: {message: "Not Found", status: 302} if @warehouse_order_document.blank?
    else
      render json: {message: "Please provide valid tag number", status: 204}
    end
  end

  def pending_grade
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_grade).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def rtv
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_rtv).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def restock
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_restock).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def repair
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_repair).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def liquidation
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_liquidation).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def ewaste
    inventory_status = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_e_waste_compliance_document).first
    @inventories = Inventory.where("details ->> 'status' = ?", inventory_status.original_code).order('updated_at desc')
    render json: @inventories
  end

  def pending_issues
    inventory_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    @inventories = Inventory.includes(:inventory_grading_details, :inventory_documents, :vendor_returns, :repairs, :replacements, :redeploys, :markdowns, :e_wastes, :pending_dispositions, :liquidations).where(distribution_center_id: distribution_centers_ids, status_id: inventory_status.id).where("details ->> 'stock_transfer_order_number' is NULL").order('updated_at desc')

    render json: @inventories
  end

  def assign_new_stn
    begin
      ActiveRecord::Base.transaction do
        gate_pass = GatePass.opened.includes(:inventories, :gate_pass_inventories).where("lower(client_gatepass_number) = ?", params["new_stn_number"].downcase).first
        document_type = LookupValue.where(code: Rails.application.credentials.update_stn_file_types_stn_update_document).first
        if gate_pass.present?
          params['inventory_ids'].each do |id|
            inventory = Inventory.find_by_id(id)
            old_gatepass = inventory.gate_pass
            old_gatepass_inventory = inventory.gate_pass_inventory
            old_gatepass_inventory.inwarded_quantity = old_gatepass_inventory.inwarded_quantity - 1
            old_gatepass_inventory.update_gate_pass_inventory_status

            gate_pass.details = old_gatepass.details
            gate_pass.save

            gate_pass_inventory = gate_pass.gate_pass_inventories.where(sku_code: inventory.sku_code).last

            if gate_pass_inventory.blank?
              client_sku = ClientSkuMaster.where("lower(code) = ?", inventory.sku_code.downcase).last
              gatepass_inventory_status_excess_received =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
              gate_pass_inventory = gate_pass.gate_pass_inventories.new(distribution_center_id: gate_pass.distribution_center_id, client_id: gate_pass.client_id, user_id: current_user.id, sku_code: inventory.sku_code, item_description: client_sku.sku_description, quantity: 0, status: gatepass_inventory_status_excess_received.original_code, status_id: gatepass_inventory_status_excess_received.id, map: client_sku.mrp, client_category_id: client_sku.client_category_id,
              ean: client_sku.ean, client_category_name: client_sku.client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id))
              gate_pass_inventory.details = {"own_label"=> client_sku.own_label}
              gate_pass_inventory.save
            end

            client_category =  gate_pass_inventory.client_category

            inventory.details['stn_number'] = params['new_stn_number']
            inventory.details["issue_type"] = nil
            inventory.details["grn_received_time"] = nil
            inventory.details["grn_received_user_id"] = nil
            inventory.details["grn_received_user_name"] = nil
            inventory.details["grn_number"] = nil
            inventory.details["source_code"] = gate_pass.source_code
            inventory.details["destination_code"]
            inventory.details['update_stn_remarks'] = params['stn_remarks']
            inventory.details["dispatch_date"] = gate_pass_inventory.gate_pass.dispatch_date.strftime("%Y-%m-%d %R")
            inventory.details["source_code"] = gate_pass_inventory.gate_pass.source_code
            inventory.details["destination_code"] = gate_pass_inventory.gate_pass.destination_code
            inventory.details["brand"] = gate_pass_inventory.brand
            inventory.details["client_sku_master_id"] = gate_pass_inventory.client_sku_master_id.try(:to_s)
            inventory.details["ean"] = gate_pass_inventory.ean
            inventory.details["merchandise_category"] = gate_pass_inventory.merchandise_category
            inventory.details["merch_cat_desc"] = gate_pass_inventory.merch_cat_desc
            inventory.details["line_item"] = gate_pass_inventory.line_item
            inventory.details["document_type"] = gate_pass_inventory.document_type
            inventory.details["site_name"] = gate_pass_inventory.site_name
            inventory.details["consolidated_gi"] = gate_pass_inventory.consolidated_gi
            inventory.details["sto_date"] = gate_pass_inventory.sto_date
            inventory.details["group"] = gate_pass_inventory.group
            inventory.details["group_code"] = gate_pass_inventory.group_code
            inventory.details["own_label"] = (gate_pass_inventory.details.present? ? gate_pass_inventory.details["own_label"] : nil)

            inventory.save
            grn_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first
            inventory.update_attributes(status_id: grn_status.id, status: grn_status.original_code, user_id: current_user.id, gate_pass_id: gate_pass.id, distribution_center_id: gate_pass_inventory.distribution_center_id,
                                client_id: gate_pass_inventory.client_id, sku_code: gate_pass_inventory.sku_code, item_description: gate_pass_inventory.item_description,
                                quantity: 1, gate_pass_inventory_id: gate_pass_inventory.id ,item_price: gate_pass_inventory.map, client_category_id: client_category.id)

            inventory.inventory_statuses.where(is_active: true).update_all(is_active: false) if inventory.inventory_statuses.present?

            inventory.inventory_statuses.create(status_id: grn_status.id, user_id: current_user.id,
              distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})

            # gate_pass_inventory.quantity = gate_pass_inventory.quantity + 1
            gate_pass_inventory.inwarded_quantity = gate_pass_inventory.inwarded_quantity + 1
            gate_pass_inventory.save
            gate_pass_inventory.update_gate_pass_inventory_status

            old_gatepass.update_status
            gate_pass.update_status

            if params["files"].present?
              params["files"].each do |document|
                attachment = inventory.inventory_documents.new(document_name_id: document_type.id)
                attachment.attachment = document
                attachment.save
              end
            end
          end

          inventory_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
          distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
          @inventories = Inventory.includes(:inventory_grading_details, :inventory_documents, :vendor_returns, :repairs, :replacements, :redeploys, :markdowns, :e_wastes, :pending_dispositions, :liquidations).where(distribution_center_id: distribution_centers_ids, status_id: inventory_status.id).where("details ->> 'stock_transfer_order_number' is NULL").order('updated_at desc')
          inventories = ActiveModel::SerializableResource.new(@inventories, each_serializer: Api::V1::Warehouse::InventorySerializer).as_json
          render :json => {
            inventories: inventories[:inventories],
            status: 200
          }

        else
          inventory_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
          distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
          @inventories = Inventory.includes(:inventory_grading_details, :inventory_documents, :vendor_returns, :repairs, :replacements, :redeploys, :markdowns, :e_wastes, :pending_dispositions, :liquidations).where(distribution_center_id: distribution_centers_ids, status_id: inventory_status.id).where("details ->> 'stock_transfer_order_number' is NULL").order('updated_at desc')

          inventories = ActiveModel::SerializableResource.new(@inventories, each_serializer: Api::V1::Warehouse::InventorySerializer).as_json
          render :json => {
            inventories: inventories[:inventories],
            status: 402
          }

        end
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end

  end

  def alert_inventories
    low_inventories =[]
    med_inventories =[]
    high_inventories =[]

    low_inventories = Repair.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+Liquidation.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+Replacement.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+Insurance.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+VendorReturn.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+Redeploy.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)+Markdown.where("details->>'criticality' = ? ",'Low').collect(&:inventory_id)
    med_inventories = Repair.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+Liquidation.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+Replacement.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+Insurance.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+VendorReturn.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+Redeploy.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)+Markdown.where("details->>'criticality' = ? ",'Medium').collect(&:inventory_id)
    high_inventories = Repair.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+Liquidation.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+Replacement.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+Insurance.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+VendorReturn.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+Redeploy.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)+Markdown.where("details->>'criticality' = ? ",'High').collect(&:inventory_id)

    inv_arr = low_inventories + med_inventories + high_inventories
    alert_inventories = Inventory.where(id:inv_arr)
    render json: alert_inventories
  end

  def inventory_status_count
    distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    info_type = current_user.roles.pluck(:code).include?('default_user') ? 'Inventory Status Default User' : 'Inventory Status Central Admin'
    bucket_informations = BucketInformation.where("info_type = ? and distribution_center_id in (?)", info_type, distribution_center_ids)
    sum_hash = {}
    bucket_informations.each do |bucket_information|
      bucket_status = bucket_information.bucket_status
      sum_hash = sum_stats(bucket_status, sum_hash)
    end
    render json: sum_hash
  end

  def disposition_criticality_count
    distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    info_type = current_user.roles.pluck(:code).include?('default_user') ? 'Disposition Status Default User' : 'Disposition Status Central Admin'
    bucket_informations = BucketInformation.where("info_type = ? and distribution_center_id in (?)", info_type, distribution_center_ids)
    sum_hash = {}
    bucket_informations.each do |bucket_information|
      bucket_status = bucket_information.bucket_status
      sum_hash = sum_stats(bucket_status, sum_hash)
    end
    render json: sum_hash
  end

  def sum_stats(*hashes)
    hashes.reduce({}) do |sums, stats|
      sums.merge(stats) do |_, prev_hsh, new_hsh|
        prev_hsh.merge(new_hsh) {|_, prev_val, new_val| prev_val + new_val }
      end
    end
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Disposition', 'RTV', "Pending Transfer Out"]).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  def bucket_alert_records
    result = Hash.new(0)
    Inventory::STATUS_LOOKUP_KEY_NAMES.each do |key, value|

      result[key] = {}

      temp_count = eval("#{AlertConfiguration::DISPOSITION_BUCKET[key]}.where(distribution_center_id:#{current_user.distribution_centers.collect(&:id)}, is_active:#{true})").where("details->>'criticality' IS NOT NULL")

      temp_count.each do |tc|
        rpa_location = tc.details["destination_code"]
        if !rpa_location.present?
        elsif !result[key][rpa_location].nil?
          result[key][rpa_location] << tc
        else
          result[key][rpa_location] = []
          result[key][rpa_location] << tc
        end
      end
    end



    result_arr = []
    result.each do |key,value|
      disposition = key

      value.each do |key1,value1|
        location = key1
        status_arr=[]
        status_arr = LookupKey.find_by(name: Inventory::STATUS_LOOKUP_KEY_NAMES[disposition]).lookup_values.order(:position).collect(&:original_code)
#value1.collect(&:status).uniq
        status_arr.each do |value2|
          temp_hash=Hash.new()
          high = 0
          low = 0
          medium = 0
          value1.select{|l| l.status == value2}.each do |v3|
            criticality = v3.details["criticality"]
            if criticality == "High"
              high = high + 1
            elsif criticality == "Medium"
              medium = medium + 1
            elsif criticality == "Low"
              low = low + 1
            end
          end

          temp_hash["disposition"] = disposition
          temp_hash["location"] = location
          temp_hash["status"] = value2
          temp_hash["high"] = high
          temp_hash["medium"] = medium
          temp_hash["low"] = low

          result_arr << temp_hash if high + medium + low != 0
        end

      end
    end

    render json: result_arr
  end

  private

  def check_user_accessibility(items, detail)
    result = []
    items.each do |item|
      origin_location_id = [item.distribution_center_id]
      if ( (detail["grades"].include?("All") ? true : detail["grades"].include?(item.grade) ) && ( detail["brands"].include?("All") ? true : detail["brands"].include?(item.details["brand"]) ) && ( detail["warehouse"].include?(0) ? true : detail["warehouse"].include?(item.distribution_center_id) ) && ( detail["origin_fields"].include?(0) ? true : detail["origin_fields"].include?(origin_location_id)) )
        result << item.id
      end
    end
    return result
  end


  def get_distribution_centers(disposition)
    user = User.includes(:distribution_center_users, :distribution_centers).select(:id).where("id = ?", current_user.id).first
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : user.distribution_centers.select(:id).collect(&:id)
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name)
      id = []
      user.distribution_center_users.select(:id, :details).where(distribution_center_id: @distribution_center_ids).each do |distribution_center_user|
        if disposition == "RTV"
          @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "RTV" || d["disposition"] == "All"}.last
        elsif disposition == "Brand Call-Log"
          @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Brand Call-Log" || d["disposition"] == "All"}.last
        else
          @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == disposition || d["disposition"] == "All"}.last
        end
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? user.distribution_centers.collect(&:id) : @distribution_center_detail["warehouse"]
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : user.distribution_centers.collect(&:id)
    end
  end

end
