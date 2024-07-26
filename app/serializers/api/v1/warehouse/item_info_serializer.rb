class Api::V1::Warehouse::ItemInfoSerializer < ActiveModel::Serializer
  include Utils::Formatting
  attributes :item_details, :packaging_info, :item_condition_info, :functional_info, :accessories_info, :outward_details, :item_journey

  def item_details
    bucket = object.get_current_bucket
    changed_sku_code = object.details["changed_sku_code"]
    sku_code = object.sku_code.to_s
    
    item_details = {
      "Item Details" => {
        "Item ID"             => object.tag_number,
        "Serial Number 1"     => object.serial_number,
        "Serial Number 2"     => object.serial_number_2,
        "Article Code"        => sku_code,
        "Changed Article Code"=> changed_sku_code,
        "Article Description" => object.item_description,
        "STN Number"          => object.details['stn_number'],
        "OBD Date"            => (object.gate_pass.dispatch_date.strftime("%d/%b/%Y") rescue ''),
        "GRN Date"            => object.details['grn_submitted_date'],
        "Return Reason"       => object.return_reason,
      },
      "Inward Details" => {
        "Customer Invoice" => invoice_number,
        "Checklist"        => checklist.present? ? checklist.reference_number : "",
        "NRGP"             => nrgp_number.present? ? nrgp_number.reference_number : "",
        "OBD"              => obd_number.present? ? obd_number.reference_number : "",
        "SR Number"        => object.sr_number,
        "Grade"            => object.grade,
        "Toat Number"      => object.toat_number,
        "Issue State"      => object.details["issue_type"],
        "Graded By"        => (User.find_by(username: object.pending_receipt_document_item.details['inward_user_name']).full_name rescue ''),
        "Graded At"        => (object.pending_receipt_document_item.details['inward_grading_time'].to_date.strftime("%d/%b/%Y") rescue ''),
        "GRN Submitted By" => (User.find_by(id: object.details['grn_submitted_user_id']).full_name rescue ''),
        "GRN Updated By"   => (User.find_by(id: object.details['grn_submitted_user_id']).full_name rescue ''),
      },
      "Disposition Details" => {
        "Disposition"        => (object.get_disposition(bucket) rescue ""),
        "Disposition Status" => (object.get_status(bucket) rescue ""),
        "Ageing"             => (get_bucket_ageing(bucket) rescue ""),
        "Alert"              => (bucket.details["criticality"] rescue ""),
      },
      "Attachments" => {
        "invoice_attachment"   => document.present? ? document.attachment.url : "",
        "checklist_attachment" => checklist.present? ? checklist.attachment.url : "",
        "nrgp_attachment"      => nrgp_number.present? ? nrgp_number.attachment.url : "",
        "obd_attachment"       => obd_number.present? ? obd_number.attachment.url : "",
        "is_replaced"          => object.replacement.present?,
      },
    }
    item_details['Item Details'].delete("Changed Article Code") if Rails.application.credentials.is_client_decathlon.blank?
    if object.replacement.present?
      replace = Replacement.where("details->>'old_replacement_id' = ?", object.replacement.id.to_s).last

      if replace.present?
        replacement_details = {
          "Replacement Details" => {
            "Item ID"             => replace.tag_number,
            "Serial Number 1"     => replace.serial_number,
            "Serial Number 2"     => replace.serial_number_2,
            "Article Code"        => replace.sku_code,
            "Article Description" => replace.item_description,
          }
        }

        item_details.merge!(replacement_details)
      end
    end

    return item_details
  end

  def packaging_info
    packaging_details = {"Packaging" => [], "Images" => [], "Output" => ''}
    object.inventory_grading_details.each do |grading_detail|
      packaging_key = (grading_detail.details["final_grading_result"].keys.include?("Packaging Condition") ? "Packaging Condition" : "Packaging" rescue "Packaging")
      packaging_details["Output"] = grading_detail.details["final_grading_result"][packaging_key][0]["output"] rescue []
      if (grading_detail.details["final_grading_result"][packaging_key].present? rescue false)
        grading_detail.details["final_grading_result"][packaging_key].each_with_index do |packaging_data, ind|
          if packaging_key == "Packaging"
            packaging_data['annotations'].each do |a|
              result = {
                "position" => "#{a['orientation']} - #{a['direction']}",
                "value" => a['text'],
                "image_url" =>  a['src']
              }
              packaging_details["Packaging"].push(result)
              packaging_details["Images"].push(result["image_url"])
              packaging_details["Images"]
            end
          else
            result = {
              "position" => packaging_data["test"].present? ? packaging_data["test"] : 'N/A',
              "value" => packaging_data["value"].present? ? packaging_data["value"] : '',
              "image_url" => packaging_data["imageHolders"].present? ? packaging_data["imageHolders"].map{|img| img["imageSrc"]} : ''
            }
            packaging_details["Packaging"].push(result)
            packaging_data["imageHolders"].each do |img|
              packaging_details["Images"].push(img["imageSrc"]) if img["imageSrc"].present?
            end if packaging_data["imageHolders"].present?
          end
        end
      end
    end
    return packaging_details
  end

  def item_condition_info
    packaging_details = {"ItemCondition" => [], "Images" => [], "Output" => ''}
    object.inventory_grading_details.each do |grading_detail|
      item_condition_key = (grading_detail.details["final_grading_result"].keys.include?("Physical Condition") ? "Physical Condition" : "Item Condition" rescue "Item Condition")
      packaging_details["Output"] = grading_detail.details["final_grading_result"][item_condition_key][0]["output"] rescue []
      if (grading_detail.details["final_grading_result"][item_condition_key].present? rescue false)
        grading_detail.details["final_grading_result"][item_condition_key].each_with_index do |packaging_data, ind|
          if item_condition_key == "Item Condition"
            packaging_data['annotations'].each do |a|
              result = {
                "position" => "#{a['orientation']} - #{a['direction']}",
                "value" => a['text'],
                "image_url" =>  a['src']
              }
              packaging_details["ItemCondition"].push(result)
              packaging_details["Images"].push(result["image_url"])
              packaging_details["Images"]
            end
          else
            result = {
              "position" => packaging_data["test"].present? ? packaging_data["test"] : 'N/A',
              "value" => packaging_data["value"].present? ? packaging_data["value"] : '',
              "image_url" => packaging_data["imageHolders"].present? ? packaging_data["imageHolders"].map{|img| img["imageSrc"]} : ''
            }
            packaging_details["ItemCondition"].push(result)
            packaging_data["imageHolders"].each do |img|
              packaging_details["Images"].push(img["imageSrc"]) if img["imageSrc"].present?
            end if packaging_data["imageHolders"].present?
          end
        end
      end
    end
    return packaging_details
  end

  def functional_info
    packaging_details = {"Functional" => [], "Images" => [], "Output" => ''}
    object.inventory_grading_details.each do |grading_detail|
      functional_key = (grading_detail.details["final_grading_result"].keys.include?("Functional Condition") ? "Functional Condition" : "Functional" rescue "Functional")
      packaging_details["Output"] = grading_detail.details["final_grading_result"][functional_key][0]["output"] rescue []
      if (grading_detail.details["final_grading_result"][functional_key].present? rescue false)
        grading_detail.details["final_grading_result"][functional_key].each_with_index do |packaging_data, ind|
          result = {
            "position" => packaging_data["test"].present? ? packaging_data["test"] : 'N/A',
            "value" => packaging_data["value"].present? ? packaging_data["value"] : '',
          }
          packaging_details["Functional"].push(result)
        end
      end
    end
    return packaging_details
  end

  def accessories_info
    packaging_details = {"Accessories" => [], "Images" => [], "Output" => ''}
    object.inventory_grading_details.each do |grading_detail|
      packaging_details["Output"] = grading_detail.details["final_grading_result"]["Accessories"][0]["output"] rescue []
      if (grading_detail.details["final_grading_result"]["Accessories"].present? rescue false)
        grading_detail.details["final_grading_result"]["Accessories"].each_with_index do |packaging_data, ind|
          result = {
            "position" => packaging_data["test"].present? ? packaging_data["test"] : 'N/A',
            "value" => packaging_data["value"].present? ? packaging_data["value"] : '',
          }
          packaging_details["Accessories"].push(result)
        end
      end
    end
    return packaging_details
  end


  def outward_details
    warehouse_order_item = WarehouseOrderItem.where(inventory_id: object.id).last
    warehouse_order = warehouse_order_item.warehouse_order rescue nil
    out_w = {}
    if warehouse_order.present?
      warehouse_order_documents = warehouse_order.warehouse_order_documents
      consignment = WarehouseConsignment.find_by(id: warehouse_order.warehouse_consignment_id)
      out_w = {
        "Outward Details" => {

          "Order Number" => warehouse_order.reference_number,
          "Order Date" => warehouse_order.created_at.strftime("%d/%b/%Y"),
          "Pack Date" => "",
          "Dispatch Date" => (warehouse_order.details["dispatch_initiate_date"].present? ? warehouse_order.details["dispatch_initiate_date"].to_date.strftime("%d/%b/%Y") : ""  rescue ''),
          "Vendor Details" => warehouse_order.vendor_code,
          "Box Number" => warehouse_order_item.dispatch_box&.box_number,
          "Dispatched By" => (warehouse_order.details['dispatched_by_user_name'] rescue ''),
          "Picked and Packed By" => (warehouse_order.details['packed_by_user_name'] rescue '')

        },

        "Outward Documents" => {

          "RTN Copy" => warehouse_outward_documents(warehouse_order, "RTN"),
          "GI Copy" => warehouse_outward_documents(warehouse_order, "GI"),
          "NRGP" => warehouse_outward_documents(warehouse_order, "NRGP"),
          "LR" => warehouse_outward_documents(warehouse_order, "LR"),
          "E-Way Bill" => warehouse_outward_documents(warehouse_order, "E-Way Bill"),
          "Invoice" => warehouse_outward_documents(warehouse_order, "Invoice"),
          "STO Copy" => warehouse_outward_documents(warehouse_order, "STO")
        },

        "Transporter Details" => {

          "Transporter Name" => consignment.present? ? consignment.transporter : '',
          "Transporter Phone Number" => consignment.present? ? consignment.driver_contact_number: '',
          "Vehicle No." => consignment.present? ? consignment.vehicle_number : '',
          "Lorry Receipt No." => consignment.present? ? consignment.truck_receipt_number : '',
          "Gate Pass" => warehouse_order.gatepass_number
        }

      }
    end
    return out_w
  end

  def item_journey
    item_journey_info = []

    object.brand_call_logs.each do |brand_call_log|
      brand_call_log.brand_call_log_histories.order(created_at: :desc).each do |history|
        status = LookupValue.find_by(id: history.status_id)
        next if status.blank?

        case status.original_code
        when "Pending Information"
          file_type = "DOA Certificate"
        when "Pending Inspection"
          attachments = [{ name: brand_call_log.inspection_report_url.split('/').last, url: brand_call_log.inspection_report_url }] if brand_call_log.inspection_report.present?
        end

        attachments = brand_call_log.rtv_attachments.where(attachment_file_type: file_type).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }} if file_type

        journey_data = { "disposition" => "Brand Call Log", "status" => status.original_code, "entry_date" => format_date(history.created_at.to_date), "attachments": attachments, "comment": "N/A", "status_changed_by" => history.details["status_changed_by_user_name"], "created_at" => history.created_at }

        item_journey_info << journey_data
      end
    end
    
    object.vendor_returns.each do |vendor_return|
      vendor_return.vendor_return_histories.order(created_at: :desc).each do |histroy|
        previous_history = vendor_return.vendor_return_histories.where("id < ?", histroy.id).last

        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        if status.original_code == "Pending Settlement"
          comment   = vendor_return.settlement_remark
          file_type = "Settlement"
        elsif status.original_code == "Pending Claim"
          file_type = "Claim"
        elsif ["Pending Dispatch", "Pending Disposition", "RTV Closed"].include?(status.original_code)
          comment   = vendor_return.disposition_remark
          file_type = "Disposition"
        elsif status.original_code == "Pending Brand Inspection"
          comment = vendor_return.brand_inspection_remarks
        end

        attachments = vendor_return.rtv_attachments.where(attachment_file_type: file_type).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }} if file_type

        status_original_code = status.original_code == "RTV Closed" ? previous_history.status.original_code : status.original_code rescue status.original_code

        disposition_status = if LookupValue.where(code: ['dispatch_status_pending_pick_and_pack', 'dispatch_status_pending_dispatch', 'dispatch_status_completed']).pluck(:id).include?(histroy.status_id)
          if status.original_code == "Completed"
            sub_status = "--"
            "Dispatched"
          else
            sub_status = status.original_code
            "Dispatch"
          end
        elsif ["Pending Settlement", "Pending Dispatch", "Pending Pick up"].include?(status_original_code)
          "RTV"
        else
          "Brand-Call-Log"
        end

        sub_status = sub_status || get_status_value(vendor_return, status.original_code)

        next if (sub_status == "RTV Closed" && disposition_status == "Brand-Call-Log")

        journey_data = { "disposition" => disposition_status, "status" => sub_status, "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments" => attachments, "comment" => comment, "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.liquidations.each do |liquidation|
      liquidation.liquidation_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        disposition_status = if LookupValue.where(code: ['dispatch_status_pending_pick_and_pack', 'dispatch_status_pending_dispatch', 'dispatch_status_completed']).pluck(:id).include?(histroy.status_id)
          if status.original_code == "Completed"
            sub_status = "--"
            "Dispatched"
          else
            sub_status = status.original_code
            "Dispatch"
          end
        else
          "Liquidation"
        end

        journey_data = { "disposition" => disposition_status, "status" => sub_status || get_status_value(liquidation, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.markdowns.each do |markdown|
      markdown.markdown_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        if status.original_code == "Pending Transfer Out Destination"
          comment   = markdown.destination_remark
          file_type = "Markdown Destination"
        end

        attachments = markdown.markdown_attachments.where(attachment_file_type: file_type).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }} if file_type

        journey_data = { "disposition" => "Markdown", "status" => get_status_value(markdown, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments": attachments, "comment": comment, "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.repairs.each do |repair|
      repair.repair_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        comment = case status.original_code
        when "Pending Repair Initiation"
          repair.details['pending_initiation_remark']
        when "Pending Repair Quotation"
          repair.details['pending_quotation_remark']
        when "Pending Repair Approval"
          repair.details['pending_approval_remark']
        when "Pending Repair Grade"
          repair.details['pending_repair_remark']
        when "Pending Repair Disposition"
          repair.details['pending_disposition_remark']
        end

        attachments = repair.repair_attachments.where(attachment_type_id: histroy.status_id).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }}

        journey_data = { "disposition" => "Repair", "status" => get_status_value(repair, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments": attachments, "comment": comment, "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.insurances.each do |insurance|
      insurance.insurance_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        case status.original_code
        when "Pending Information"
          attachments = insurance.insurance_attachments.map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }}
          attachments += insurance.get_incident_images + insurance.get_incident_videos
        when "Pending Inspection"
          attachments = [{ name: insurance.inspection_report_url.split('/').last, url: insurance.inspection_report_url }] if insurance.inspection_report.present?
        end

        journey_data = { "disposition" => "Insurance", "status" => status.original_code, "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments": attachments, "comment": "N/A", "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.replacements.each do |replacement|
      replacement.replacement_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        if status.original_code == "Pending Replacement Call Log"
          comment = replacement.call_log_remarks
          type    = "Replacement Call Log"
        elsif status.original_code == "Pending Replacement Replaced"
          comment = replacement.replacement_remark
        elsif status.original_code == "Pending Replacement Disposition"
          comment = replacement.disposition_remark
          type    = "Replacement Disposition"
        elsif status.original_code == "Pending Replacement Approved"
          comment = replacement.action_remark
          type    = "Replacement Approved"
        elsif status.original_code == 'Pending Replacement Inspection'
          type = "Replacement Inspection"
        end

        attachments = replacement.replacement_attachments.where(attachment_type: type).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }} if type

        journey_data = { "disposition" => "Replacement", "status" => get_status_value(replacement, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments": attachments, "comment": comment, "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.redeploys.each do |redeploy|
      redeploy.redeploy_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        if status.original_code == "Pending Redeploy Destination"
          comment   = redeploy.pending_destination_remarks
          file_type = "Pending Redeploy Destination"
        end

        disposition_status = if LookupValue.where(code: ['dispatch_status_pending_pick_and_pack', 'dispatch_status_pending_dispatch', 'dispatch_status_completed']).pluck(:id).include?(histroy.status_id)
          if status.original_code == "Completed"
            sub_status = "--"
            "Dispatched"
          else
            sub_status = status.original_code
            "Dispatch"
          end
        else
          "Redeploy"
        end

        attachments = redeploy.redeploy_attachments.where(attachment_file_type: file_type).map{ |t| { name: t.attachment_file_url.split('/').last, url: t.attachment_file_url }} if file_type

        journey_data = { "disposition" => disposition_status, "status" => sub_status || get_status_value(redeploy, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "attachments": attachments, "comment": comment, "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.e_wastes.each do |e_waste|
      e_waste.e_waste_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)

        journey_data = { "disposition" => "E-Waste", "status" => get_status_value(e_waste, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.saleables.each do |saleable|
      saleable.saleable_histories.order(created_at: :desc).each do |history|
        status = LookupValue.find_by(id: history.status_id)

        journey_data = { "disposition" => "Saleable", "status" => get_status_value(saleable, status.original_code), "entry_date" => history.created_at.strftime("%d/%b/%Y"), "status_changed_by" => history.details["status_changed_by_user_name"], "created_at" => history.created_at }

        item_journey_info << journey_data
      end
    end

    object.capital_assets.each do |capital_asset|
      capital_asset.capital_asset_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        journey_data = { "disposition" => "capital_asset", "status" => get_status_value(capital_asset, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end

    object.cannibalizations.each do |cannibalization|
      cannibalization.cannibalization_histories.order(created_at: :desc).each do |histroy|
        status = LookupValue.find_by(id: histroy.status_id)
        next if status.blank?

        journey_data = { "disposition" => "cannibalization", "status" => get_status_value(cannibalization, status.original_code), "entry_date" => histroy.created_at.strftime("%d/%b/%Y"), "status_changed_by" => histroy.details["status_changed_by_user_name"], "created_at" => histroy.created_at }

        item_journey_info << journey_data
      end
    end
    
    lookup_key = LookupKey.find_by(code: "DISPATCH_STATUS")
    dispatch_statuses = object.inventory_statuses.joins(:status).where("lookup_values.id IN (?)", lookup_key.lookup_values.pluck(:id))
    wo_item = object.warehouse_order_items.last
    dispatch_statuses.each do |inventory_status|
      status = inventory_status.status
      if status.original_code == "Pending Dispatch"
        dispatch_box = wo_item.dispatch_box
        attachments = [{ name: dispatch_box.handover_document_url.split('/').last, url: dispatch_box.handover_document_url }] if dispatch_box&.handover_document.present?
      end
      journey_data = { "disposition" => "Dispatch", "status" => status.original_code, "entry_date" => format_date(inventory_status.created_at.to_date), "attachments": attachments || [], "comment": "N/A", "status_changed_by" => inventory_status.user&.full_name, "created_at" => inventory_status.created_at }
      
      item_journey_info << journey_data
    end

    item_journey_info.sort_by! { |k| k["created_at"]}

    previous_journey = nil

    item_journey_info.map do |journey|
      tat_days = (journey["created_at"].to_date - previous_journey["created_at"].to_date).to_i.to_s + ' Days' rescue nil if previous_journey.present?

      previous_journey = journey

      journey.merge({"tat_days" => tat_days })
    end
  end

  private

  def get_bucket_ageing(bucket)
    status_id = bucket.status_id
    if bucket.class.name == "VendorReturn"
      histroy = bucket.vendor_return_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Markdown"
      histroy = bucket.markdown_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Liquidation"
      histroy = bucket.liquidation_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Insurance"
      histroy = bucket.insurance_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Repair"
      histroy = bucket.repair_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Replacement"
      histroy = bucket.replacement_histories.where(status_id: status_id).last
    elsif bucket.class.name == "Redeploy"
      histroy = bucket.redeploy_histories.where(status_id: status_id).last
    elsif bucket.class.name == "EWaste"
      histroy = bucket.e_waste_histories.where(status_id: status_id).last
    end
    if histroy.blank?
      histroy = bucket.updated_at
    else
      histroy = histroy.created_at
    end

    return "#{(Date.today.to_date - histroy.to_date).to_i} d (#{(Date.today.to_date - bucket.inventory.details["grn_received_time"].to_date).to_i} d)" if histroy.present?
  end

  def invoice_number
    if object.details['invoice_number'].present?
      return object.details['invoice_number']
    elsif object.details['document_text'].present?
      return object.details['document_text']
    else
      value = inventory_doc_values.where(original_code: "Customer Invoice").last
      document = object.inventory_documents.where(document_name_id: value.id).last
      return document.present? ? document.reference_number : ''
    end
  end

  def document
    value = inventory_doc_values.where(original_code: "Customer Invoice").last
    document = object.inventory_documents.where(document_name_id: value.id).last
    return document if document.present?
  end

  def nrgp_number
    value = inventory_doc_values.where(original_code: "NRGP").last
    document = object.inventory_documents.where(document_name_id: value.id).last
    return document if document.present?
  end

  def obd_number
    value = inventory_doc_values.where(original_code: "OBD").last
    document = object.inventory_documents.where(document_name_id: value.id).last
    return document if document.present?
  end

  def checklist
    value = inventory_doc_values.where(original_code: "Check List").last
    document = object.inventory_documents.where(document_name_id: value.id).last
    return document if document.present?
  end

  def warehouse_outward_documents(order, doc_type)
    doc_hash = {}
    obj = order.warehouse_order_documents.where(document_name: doc_type).last
    if obj.present?
      doc_hash['number'] = obj.reference_number
      doc_hash['attachment'] = obj.attachment_url
    end
    return doc_hash
  end

  def warehouse_invoice(order)
    document = order.warehouse_order_documents.where(document_name: "Invoice").last
    document.reference_number if document.present?
  end

  def inventory_doc_values
    key = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    return key.lookup_values
  end

  def get_status_value(bucket, status)
    case bucket.class.name
    when "VendorReturn"
      if status == "Pending Dispatch"
        return "Pending Confirmation"
      elsif status == "Pending Settlement"
        return "Pending Finalisation"
      elsif status == "Pending Claim"
        return "Pending Call Log"
      elsif status == "Pending Call Log"
        return "Update Call Log"
      elsif status == "Pending Brand Inspection"
        return "Pending Inspection"
      elsif ["Pending Brand Resolution", "Pending Brand Approval"].include?(status)
        return "Pending Brand Resolution"
      elsif status == "RTV Closed"
        return "RTV Closed"
      else
        return bucket.status
      end

    when "Insurance"
      if status == "Pending Insurance Submission"
        return "Pending Claim Registration"
      elsif status == "Pending Insurance Call Log"
        return "Update Claim Registration"
      elsif status == "Pending Call Log"
        return "Pending Brand Resolution"
      elsif status == "Pending Insurance Inspection"
        return "Pending Surveyor Inspection"
      elsif status == "Pending Insurance Approval"
        return "Pending Claim Resolution"
      elsif ["Pending Insurance Dispatch", "Pending Insurance Disposition"].include?(status)
        return "Pending Manual Disposition"
      else
        return status
      end

    when "Replacement"
      if status == "Pending Replacement Disposition "
        return "Pending Redeployment"
      elsif status == 'Pending Replacement Approved'
        return 'Pending Replacement'
      else
        return status
      end

    when "Repair"
      if status == "Pending Repair Initiation"
        return "Pending Repair Inspection"
      elsif status == "Pending Repair"
        return "Pending Repair"
      elsif status == "Pending Redeployment"
        return "Pending Redeployment"
      else
        return status
      end

    when "Redeploy"
      if status == "Pending Redeploy Destination"
        return "Pending Redeploy Dispatch"
      else
        return status
      end

    when "Restock"
      if status == "Pending Restock Destination"
        return "Pending Restock Location"
      elsif status == "Pending Restock Dispatch"
        return "Dispatch"
      else
        return status
      end

    when "Liquidation"
      if status == "Lot Creation" || status == 'Pending Liquidation Regrade'
        return "Pending RFQ"
      elsif status == "Lot Status"
        return "Pending Billing"
      elsif status == "Available To Sell"
        return "Pending Liquidation"
      else
        return status
      end
    else
      return status
    end
  end

end
