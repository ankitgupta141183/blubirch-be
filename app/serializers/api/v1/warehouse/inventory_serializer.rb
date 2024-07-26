class Api::V1::Warehouse::InventorySerializer < ActiveModel::Serializer
  attributes :id, :distribution_center_id, :client_id, :tag_number, :return_reason, :details, :gate_pass_id, :sku_code, :item_description, :quantity, :client_tag_number, :disposition, :grade, :serial_number, :serial_number_2, :item_price  ,:stn_number , :issue_type , :pending_issue_destination , :pending_issue_source , :pending_issue_destination , :pending_issue_aging, :brand, :sr_number, :grading_images, :inward_date, :status, :last_updated, :last_disposition, :dispatch_date, :current_bucket, :current_status, :invoice_number, :call_log_number, :is_putaway_inwarded


  def stn_number
    object.details["stn_number"]
  end

  def tag_number
    return object.tag_number.present? ? object.tag_number : "N/A"
  end
  
  def issue_type
    object.details["issue_type"]
  end

  def pending_issue_destination
    object.details["destination_code"]
  end

  def pending_issue_source
    object.details["source_code"]
  end

  def pending_issue_aging
    "#{(Date.today.to_date - object.details["grn_received_time"].to_date).to_i}d" + ' (' + "#{(Date.today.to_date - object.details["inward_grading_time"].to_date).to_i}d" + ')' rescue nil
  end

  def brand
    object.details['brand'] rescue 'NA'
    # object.client_sku_master.brand rescue nil
  end

  def inward_date
    object.created_at.strftime("%d/%b/%Y")
  end

  def last_updated
    object.updated_at.strftime("%d/%b/%Y")
  end

  def last_disposition
    case object.disposition
    when 'Brand-Call-Log'
      object.vendor_returns.last.created_at.strftime("%d/%b/%Y") if object.vendor_returns.present?
    when 'Insurance'
      object.insurances.last.created_at.strftime("%d/%b/%Y") if object.insurances.present?
    when 'RTV'
      object.vendor_returns.last.created_at.strftime("%d/%b/%Y") if object.vendor_returns.present?
    when 'Repair'
      object.repairs.last.created_at.strftime("%d/%b/%Y") if object.repairs.present?
    when 'Replacement'
      object.replacements.last.created_at.strftime("%d/%b/%Y") if object.replacements.present?
    when 'Redeploy'
      object.redeploys.last.created_at.strftime("%d/%b/%Y") if object.redeploys.present?
    when 'Pending Transfer Out'
      object.markdowns.last.created_at.strftime("%d/%b/%Y") if object.markdowns.present?
    when 'E-Waste'
      object.e_wastes.last.created_at.strftime("%d/%b/%Y") if object.e_wastes.present?
    when 'Pending Disposition'
      object.pending_dispositions.last.created_at.strftime("%d/%b/%Y") if object.pending_dispositions.present?
    when 'Liquidation'
      object.liquidations.last.created_at.strftime("%d/%b/%Y") if object.liquidations.present?
    end
      
  end

  def current_bucket
    object.get_disposition(object.get_current_bucket) rescue "N/A"
  end

  def current_status
    object.get_status(object.get_current_bucket) rescue "N/A"
  end

  def grading_images
    images = []
    object.inventory_grading_details.each do |grading_detail|
      if (grading_detail.details["final_grading_result"]["Item Condition"].present? rescue false)
        grading_detail.details["final_grading_result"]["Item Condition"].each_with_index do |packaging_data, ind|
          packaging_data['annotations'].each do |a|
            result = {
              "position" => "#{a['orientation']} - #{a['direction']}", 
              "value" => a['text'],
              "image_url" =>  a['src']
            }
            images.push(result["image_url"])
          end
        end
      end
    end
    return images
  end

  def dispatch_date
    warehouse_order = WarehouseOrderItem.where(inventory_id: object.id).last.warehouse_order rescue nil
    (warehouse_order.details["dispatch_initiate_date"].present? ? warehouse_order.details["dispatch_initiate_date"].to_date.strftime("%d/%b/%Y") : ""  rescue '')
  end


  def invoice_number
    file_types = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    invoice_file_type = file_types.lookup_values.where(original_code: "Customer Invoice").last
    doc = object.inventory_documents.where(document_name_id: instance_options[:invoice_file_type]).last
    if object.details['invoice_number'].present?
      object.details['invoice_number']
    elsif object.details['document_text'].present?
      object.details['document_text']
    elsif doc.present?
      doc.reference_number
    else
      ''
    end
  end

  def call_log_number
    record = VendorReturn.where(tag_number: object.tag_number).order("id desc").first
    record = Insurance.where(tag_number: object.tag_number).order("id desc").first if record.blank?
    record = Replacement.where(tag_number: object.tag_number).order("id desc").first if record.blank?
    if record.present?
      return record.call_log_id
    else
      return ""
    end
  end
  
  def is_putaway_inwarded
    object.putaway_inwarded?
  end

end