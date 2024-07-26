class Api::V1::Warehouse::ItemInwardController < ApplicationController
  before_action :get_prd, only: [:prd_info, :auto_inward]
  
  def prd_info
    prd_open_status = LookupValue.find_by(code: 'prd_status_open')
    data = @pending_receipt_document.as_json(only: [:id, :inward_reference_document_number])
    data[:box_linkage] = @pending_receipt_document.is_box_mapped?
    data[:total_items_in_ird] = @pending_receipt_document.pending_receipt_document_items.where(status_id: prd_open_status.id).count
    
    render json: { pending_receipt_document: data }
  end
  
  def auto_inward
    ActiveRecord::Base.transaction do
      prd_open_status = LookupValue.find_by(code: 'prd_status_open')
      prd_closed_status = LookupValue.find_by(code: 'prd_status_closed')
      good_box_numbers = @consignment_info.consignment_boxes.good_boxes.pluck(:box_number).compact
      damaged_box_numbers = @consignment_info.consignment_boxes.damaged_boxes.pluck(:box_number).compact
      
      all_items_left_in_prd = @pending_receipt_document.pending_receipt_document_items.where(status_id: prd_open_status.id)
      damaged_box_numbers = all_items_left_in_prd.where(box_number: damaged_box_numbers).pluck(:box_number).compact.uniq
      prd_items = all_items_left_in_prd.where(box_number: good_box_numbers)
      # raise 'No items found in good boxes condition' and return if prd_items.blank?
      
      items_count = prd_items.count
      items_left_in_prd = all_items_left_in_prd.count - items_count

      prd_items.each do |prd_item|
        # create inv / frwd_inv record
        prd_item.inward_item
        prd_item.update(status_id: prd_closed_status.id, status: prd_closed_status.original_code)
      end
      @consignment_info.update(status: :auto_inwarded)
      
      data = { items_left_in_prd: items_left_in_prd, damaged_box_numbers: damaged_box_numbers }
      message = "#{good_box_numbers.count} Boxes (#{items_count} items) auto inwarded successfully"
      
      render json: { data: data, message: message, status: :ok }
    end
  end
  
  def get_box_items
    raise 'Invalid Box Number' and return if params[:box_number].blank?
    pending_receipt_document = PendingReceiptDocument.find_by(id: params[:id])
    prd_open_status = LookupValue.find_by(code: 'prd_status_open')
    raise 'This document has alreday been completed.' and return if pending_receipt_document.status == 'GRN Submitted'
    
    prd_items = pending_receipt_document.pending_receipt_document_items.where(box_number: params[:box_number], status_id: prd_open_status.id)
    raise 'No items left in this box' and return if prd_items.blank?
    
    item_data = prd_items.as_json(only: %i[id sku_code sku_description serial_number1 scan_indicator imei_flag brand model client_category_id category_details])
    
    render json: { box_id: params[:box_number], items: item_data }
  end
  
  def grading_questions
    category = get_category

    # API for rule engine starts
    url = "#{Rails.application.credentials.rule_engine_url}/api/v1/grades/questions"
    serializable_resource = { client_name: 'reliance', category: category.name, grade_type: 'Warehouse' }.as_json
    response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    # API for rule engine ends
    
    if response.present?
      render json: { questions: JSON.parse(response), status: :ok }
    else
      render json: { error: "Failed to get grading questions" }, status: 422
    end
  end
  
  def compute_grade
    ActiveRecord::Base.transaction do
      prd_item = PendingReceiptDocumentItem.find_by(id: params[:id])
      raise 'Invalid ID' and return if prd_item.blank?
      category = prd_item.client_category
      
      response = fetch_grade(category, final_grading_result = params[:final_grading_result])
      if response.present?
        parsed_response = JSON.parse(response)
        final_grade = parsed_response['grade']
        grading_error = parsed_response['grading_error']
        processed_grading_result = parsed_response['processed_grading_result']
        functional = processed_grading_result['Functional Condition']
        physical = processed_grading_result['Physical Condition']
        packaging = processed_grading_result['Packaging Condition']
        accessories = processed_grading_result['Accessories']
        purchase_price = prd_item.purchase_price

        raise 'Failed to get grading details' and return if final_grade.blank?

        disposition = prd_item.disposition
        if disposition.blank?
          url = "#{Rails.application.credentials.rule_engine_url}/api/v1/dispositions"
          answers = [{ 'test_type' => 'Functional Condition', 'output' => (functional != 'NA' ? functional : 'All') },
                     { 'test_type' => 'Physical Condition', 'output' => (physical != 'NA' ? physical : 'All') },
                     { 'test_type' => 'Packaging Condition', 'output' => (packaging != 'NA' ? packaging : 'All') },
                     { 'test_type' => 'Accessories', 'output' => (accessories != 'NA' ? accessories : 'All') },
                     { 'test_type' => 'Days from Installation', 'output' => begin
                       prd_item.installation_date.strftime('%Y-%m-%d')
                     rescue StandardError
                       'All'
                     end },
                     { 'test_type' => 'Purchase Price', 'output' => (!purchase_price.nil? ? purchase_price : 'All') },
                     { 'test_type' => 'Days from Purchase Invoice', 'output' => begin
                       prd_item.purchase_invoice_date.strftime('%Y-%m-%d')
                     rescue StandardError
                       'All'
                     end },
                     { 'test_type' => 'Days from Sales Invoice', 'output' => begin
                       prd_item.sales_invoice_date.strftime('%Y-%m-%d')
                     rescue StandardError
                       'All'
                     end }]

          # serializable_resource = { client_name: 'reliance', category: category.name, brand: prd_item.brand, answers: answers }.as_json
          serializable_resource = { client_name: 'reliance', category: category.name, answers: answers }.as_json
          response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
          raise 'Disposition not found' and return if response.blank?
          prd_item.disposition = disposition = response.to_s
        end

        username = current_user.username
        item_details = prd_item.details || {}
        prd_item.grade = final_grade
        prd_item.test_user = username
        prd_item.test_date = Date.current
        item_details['final_grading_result'] = final_grading_result.as_json
        item_details['processed_grading_result'] = processed_grading_result
        item_details['inward_user_name'] = username
        item_details['inward_grading_time'] = Time.zone.now.to_s
        prd_item.details = item_details
        prd_item.save!
        
        render json: { final_grade: final_grade, disposition: disposition, processed_grading_result: processed_grading_result, status: :ok }
      else
        render json: { error: "Failed to get grading details" }, status: 422
      end
    end
  end
  
  def update_tag_number
    ActiveRecord::Base.transaction do
      prd_item = PendingReceiptDocumentItem.find_by(id: params[:id], status: 'Open')
      raise 'Invalid ID' and return if prd_item.blank?
      raise 'This document has alreday been completed. Please refresh the screen.' and return if prd_item.pending_receipt_document.status == 'GRN Submitted'
      
      prd_closed_status = LookupValue.find_by(code: 'prd_status_closed')
      prd_item.update!(tag_number: params[:tag_number], toat_number: params[:toat_number], serial_number1: params[:serial_number], status: prd_closed_status.original_code, status_id: prd_closed_status.id)
      # create inv / frwd_inv record
      prd_item.inward_item
      
      message = "Item #{prd_item.tag_number} inwarded successfully"
      render json: { message: message, status: :ok }
    end
  end

  def fetch_item
    prd = PendingReceiptDocument.where("inward_reference_document_number = ? or consignee_reference_document_number = ? or vendor_reference_document_number = ?", params[:ref_document_number], params[:ref_document_number], params[:ref_document_number]).last
    if prd.prd_items.present?
      prd_open_status = LookupValue.find_by(code: 'prd_status_open')
      prd_item = prd.pending_receipt_document_items.where("sku_code = ? or tag_number = ? and status_id = ?", params[:sku_code], params[:sku_code], prd_open_status.id).last
      if prd_item.present?
        render json: prd_item
      else
        render json: {message: "Item with specified article or tag number is alreday inwarded"}, status: 422
      end
    else
      render json: {message: "No items present for this document number"}, status: 422
    end
  end
  
  def complete_ird
    pending_receipt_document = PendingReceiptDocument.find_by(id: params[:id])
    raise 'Invalid ID.' and return if pending_receipt_document.blank?
    raise 'This document has alreday been completed. Please refresh the screen.' and return if pending_receipt_document.status == 'GRN Submitted'
    prd_open_status = LookupValue.find_by(code: 'prd_status_open')
    ird_completed_status = LookupValue.find_by(code: 'prd_status_ird_completed')
    pending_receipt_document.update!(status: ird_completed_status.original_code, status_id: ird_completed_status.id)
    
    pending_items = pending_receipt_document.pending_receipt_document_items.where(status_id: prd_open_status.id)
    
    message = "IRD completed successfully"
    render json: { message: message, generate_grn: pending_items.blank?, status: :ok }
  end
  
  def generate_grn
    ActiveRecord::Base.transaction do
      ird_completed_status = LookupValue.find_by(code: 'prd_status_ird_completed')
      pending_receipt_document = PendingReceiptDocument.find_by(id: params[:id], status_id: ird_completed_status.id)
      raise 'Please complete IRD!' and return if pending_receipt_document.blank?
      pending_receipt_document.generate_grn(current_user)
      
      message = "GRN generated successfully"
      render json: { message: message, status: :ok }
    end
  end
  
  private
  
  def get_prd
    dc_ids = current_user.distribution_centers.pluck(:id)
    @ref_document_number = params[:ref_document_number]
    @pending_receipt_document = PendingReceiptDocument.where(receiving_site_id: dc_ids).where('inward_reference_document_number = ? OR consignee_reference_document_number = ? OR vendor_reference_document_number = ?', @ref_document_number, @ref_document_number, @ref_document_number).last
    raise 'Invalid Ref Document No.' and return if @pending_receipt_document.blank?
    raise 'This document has alreday been completed.' and return if @pending_receipt_document.status == 'GRN Submitted'
    
    @consignment_info = ConsignmentInformation.where('consignee_ref_document_number like ? OR vendor_ref_number like ?', "%#{@pending_receipt_document.consignee_reference_document_number}%", "%#{@pending_receipt_document.consignee_reference_document_number}%").last
    raise 'Please complete Consignment Inwarding!' and return if @consignment_info.blank?
  end
  
  def get_category
    category = ClientCategory.find_by(id: params[:category_id])
    raise 'Invalid Category ID' and return if category.blank?
    category
  end
  
  def permissions
    {
      inwarder: {
        "api/v1/warehouse/item_inward": %i[prd_info auto_inward get_box_items grading_questions compute_grade update_tag_number complete_ird generate_grn]
      },
      central_admin: {
        "api/v1/warehouse/item_inward": %i[prd_info auto_inward get_box_items grading_questions compute_grade update_tag_number complete_ird generate_grn]
      },
      site_admin: {
        "api/v1/warehouse/item_inward": %i[prd_info auto_inward get_box_items grading_questions compute_grade update_tag_number complete_ird generate_grn]
      },
      default_user: {
        "api/v1/warehouse/item_inward": %i[prd_info auto_inward get_box_items grading_questions compute_grade update_tag_number complete_ird generate_grn]
      }
    }
  end
  
  def fetch_grade(category, final_grading_result)
    url = "#{Rails.application.credentials.rule_engine_url}/api/v1/grades/compute_grade"
    serializable_resource = { client_name: 'reliance', category: category.name, grade_type: 'Warehouse', final_grading_result: final_grading_result }.as_json
    RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
  end
end