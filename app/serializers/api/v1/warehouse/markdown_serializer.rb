class Api::V1::Warehouse::MarkdownSerializer < ActiveModel::Serializer
  
  attributes :id, :sku_code, :item_id, :article_id, :article_description, :inventory_id, :item_description, :distribution_center_id, :vendor, :tag_number, :ageing, :status, :grade, :grade_summary , :markdown_order_id, :sr_number, :source, :destination_remark, :destination_code, :serial_number, :pending_destination_ageing, :pending_dispatch_ageing, :alert_level, :ageing_dispatch

  def ageing
    "#{(Date.today.to_date - (object.inventory.details["grn_received_time"].to_date)).to_i} d" rescue "0 d"
  end

  def source
    object.inventory.details["source_code"] rescue nil
  end

  def alert_level
    object.details['criticality']
  end


  def grade_summary
    object.inventory.inventory_grading_details.last.grade_summary  rescue nil
  end

  def item_id
    object.tag_number  || 'NA'
  end

  def article_id
    object.sku_code  || "NA"
  end 

  def article_description
    object.item_description || 'NA' 
  end 

  def pending_destination_ageing
    orh = object.markdown_histories.where(status_id: LookupValue.find_by(code: Rails.application.credentials.markdown_status_pending_markdown_destination).try(:id)).first
    return '' unless orh.present?
    destination_date = orh.details["pending_markdown_destination_created_at"].present? ? (Date.today.to_date - orh.details['pending_markdown_destination_created_at'].to_date).to_i : 0 rescue nil
    inward_date = (Date.today.to_date - object.inventory.created_at.to_date).to_i
    return destination_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''
  end

  def pending_dispatch_ageing
    orh = object.markdown_histories.where(status_id: LookupValue.find_by(code: Rails.application.credentials.markdown_status_pending_markdown_dispatch).try(:id)).first
    return '' unless orh.present?
    dispatch_date = orh.details["pending_markdown_dispatch_created_at"].present? ? ( Date.today.to_date - orh.details["pending_markdown_dispatch_created_at"].to_date ).to_i : 0 rescue nil
    inward_date = (Date.today.to_date - object.inventory.created_at.to_date).to_i
    return dispatch_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''
  end

  def serial_number
    str = ''
    str = object.serial_number if object.serial_number.present?
    str = "#{object.serial_number}, #{object.serial_number_2}" if (object.serial_number_2.present? && object.serial_number.present?)
    str = object.serial_number_2 if ( object.serial_number_2.present? && str.blank?)
    return str
  end

  def ageing_dispatch
    status_change_date = object.markdown_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end

end