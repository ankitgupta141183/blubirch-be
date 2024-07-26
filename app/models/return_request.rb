class ReturnRequest < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :invoice
  belongs_to :customer_return_reason
  belongs_to :return_status, class_name: "LookupValue", foreign_key: :status_id

  #after_update :request_approval_mail, :approved_mail_to_store

  include Filterable
  include JsonUpdateable
  scope :filter_by_request_number, -> (request_number) { where("request_number ilike ?", "%#{request_number}%")}

  
  def request_approval_mail
    return_request_pending_store_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first
    return_request_pending_client_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_client_approval).first
    reminder = Reminder.where(customer_return_reason_id: self.customer_return_reason_id).first
    if self.saved_change_to_status_id?(from: return_request_pending_store_approval.try(:id), to: return_request_pending_client_approval.try(:id)) && reminder.present?
      details = Hash.new
      details.merge!({"return_reason" => self.try(:customer_return_reason).try(:name), "invoice_no" => self.details['invoice_number'], 
                      "rrn_no" => self.request_number, "email_template_id" => reminder.details['email_template_id'],
                      "approve_email_id" => reminder.details['approval_to'], "copy_email_id" => reminder.details['copy_to']})
      ReminderMailerWorker.perform_async(details) if details.present?
      #ReminderMailer.with(email_details: details).approval_email.deliver_now if details.present?
    end 
  end

  def approved_mail_to_store
    return_request_pending_client_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_client_approval).first
    return_request_pending_packaging =  LookupValue.where(code: Rails.application.credentials.return_request_pending_packaging).first
    reminder = Reminder.where(customer_return_reason_id: self.customer_return_reason_id).first
    if self.saved_change_to_status_id?(from: return_request_pending_client_approval.try(:id), to: return_request_pending_packaging.try(:id)) && reminder.present?
      details = Hash.new
      details = {template_id: reminder.details["service_executive_email_template_id"].to_s, return_request_number: self.request_number.to_s, 
        return_reason: self.try(:customer_return_reason).try(:name),
       invoice_number: self.details['invoice_number'].to_s}
      users = self.distribution_center.users
      users.each do |user|
        ReturnRequestApprovalWorker.perform_in(5.seconds, user.id, details) if details.present?
        # ReturnRequestApprovalMailer.send_mail_to_store_user(user, details).deliver_now if details.present?
      end
    end
  end

  def self.create_inventories(invoice, selected_inventories, customer_return_reason_id, user)
    status = false
    inv_grade_not_tested = LookupValue.where(code: Rails.application.credentials.inventory_grade_not_tested).first
    inventory_pending_approval_status = LookupValue.where(code: Rails.application.credentials.inventory_status_store_pending_approval).first
    return_request_pending_store_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first
    return_request = invoice.return_requests.where("customer_return_reason_id = ? and invoice_id = ?", customer_return_reason_id, invoice.try(:id)).first    
    total_inventories = (return_request.present? && return_request.details["total_inventories"].present?) ? return_request.details["total_inventories"].to_i : 0
    inventories = InvoiceInventoryDetail.where("id in (?)", selected_inventories.map {|inv| inv["id"]})
    ActiveRecord::Base.transaction do
      if return_request.present?
        return_request_number = return_request.request_number
      else
        return_request_number = "R-#{SecureRandom.hex(3)}"
        return_request = ReturnRequest.create(customer_return_reason_id: customer_return_reason_id, invoice_id: invoice.try(:id), request_number: return_request_number,
                                              distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, return_status: return_request_pending_store_approval)
      end
      if selected_inventories.present?
        selected_inventories.each do |selected_inventory|
          invoice_inventory_detail = InvoiceInventoryDetail.find(selected_inventory["id"])
          total_inventories = total_inventories + selected_inventory["return_quantity"]
            (1..selected_inventory["return_quantity"].to_i).each do |i|
              invoice_inventory_details = invoice_inventory_detail.details
              inventory_detail_hash = { "return_request_number" => return_request.request_number, "quantity" => 1,
                                        "item_price" => invoice_inventory_detail.item_price, "client_category_id" => invoice_inventory_detail.client_category_id,
                                        "client_sku_master_id" => invoice_inventory_detail.client_sku_master_id, "customer_return_reason" => return_request.try(:customer_return_reason).try(:name), customer_return_reason_id: return_request.customer_return_reason.try(:id),
                                        "invoice_id" => return_request.try(:invoice).try(:id), "invoice_number" => return_request.try(:invoice).invoice_number, "sku" => invoice_inventory_detail.try(:client_sku_master).try(:code),
                                        "packaging_status" => "Not Packed", "status" => inventory_pending_approval_status.try(:original_code), "grade" => inv_grade_not_tested.try(:original_code),"store_grading_date" => Time.now.to_s , "store_inwarding_date" => Time.now.to_s}
              inventory = Inventory.new(details: inventory_detail_hash.merge!(invoice_inventory_details), distribution_center_id: return_request.try(:invoice).distribution_center_id, client_id: return_request.try(:invoice).client_id, user: user, is_putaway_inwarded: false)            
              inventory.inventory_statuses.build(status_id: inventory_pending_approval_status.try(:id), distribution_center_id: return_request.try(:invoice).distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user: user)
              inventory.inventory_grading_details.build(grade_id: inv_grade_not_tested.try(:id), distribution_center_id: invoice.distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user: user)
              if inventory.save
                invoice_inventory_detail.update(return_quantity: (invoice_inventory_detail.return_quantity + selected_inventory["return_quantity"]))          
              end
            end
        end
      end
      status = true
      return_request_details = {"total_inventories" => total_inventories, "invoice_number" => return_request.try(:invoice).try(:invoice_number),
                                "customer_return_reason" => return_request.try(:customer_return_reason).try(:name)}
      return_request.update(details: return_request_details)
    end # Transaciton end
    if status == true
      return true, {return_request_number: return_request.request_number, disposition: "Send to Factory", inventories_count: total_inventories, invoice_number: return_request.try(:invoice).try(:invoice_number), inventories: selected_inventories} 
    else
      return false, {error: "Error in creating inventories"}
    end
  end


  def self.create_inventory_after_grading(invoice, selected_inventory, customer_return_reason_id, user, grading_involved, tag_number, final_grading_result, processed_grading_result, grade, disposition)
    status = false
    created_inventory = nil
    
    inv_grade_not_tested = grade.present? && grade != "Missing" ? LookupValue.where(original_code: grade).first : LookupValue.where(code: Rails.application.credentials.inventory_grade_not_tested).first
    
    inventory_pending_approval_status = LookupValue.where(code: Rails.application.credentials.inventory_status_store_pending_approval).first
    return_request_pending_store_approval = LookupValue.where(code: Rails.application.credentials.return_request_pending_store_approval).first
    return_request = invoice.return_requests.where("customer_return_reason_id = ? and invoice_id = ?", customer_return_reason_id, invoice.try(:id)).first    
    total_inventories = 0
    inventories = InvoiceInventoryDetail.where("id = ?", selected_inventory["id"])
    
    ActiveRecord::Base.transaction do
      if return_request.present?
        return_request_number = return_request.request_number
        total_inventories = return_request.details["total_inventories"]
      else
        return_request_number = "R-#{SecureRandom.hex(3)}"
        return_request = ReturnRequest.create(customer_return_reason_id: customer_return_reason_id, invoice_id: invoice.try(:id), request_number: return_request_number,
                                              distribution_center_id: invoice.distribution_center_id, client_id: invoice.client_id, return_status: return_request_pending_store_approval)
      end
      if selected_inventory.present?
        
          invoice_inventory_detail = InvoiceInventoryDetail.find(selected_inventory["id"])
          total_inventories = total_inventories + selected_inventory["return_quantity"]
          invoice_inventory_details = invoice_inventory_detail.details
          inventory_grading_hash = {final_grading_result: final_grading_result, processed_grading_result:processed_grading_result}
          inventory_detail_hash = { "return_request_number" => return_request.request_number,"disposition"=>disposition ,"quantity" => 1,
                                    "item_price" => invoice_inventory_detail.item_price, "client_category_id" => invoice_inventory_detail.client_category_id,
                                    "client_sku_master_id" => invoice_inventory_detail.client_sku_master_id, "customer_return_reason" => return_request.try(:customer_return_reason).try(:name), customer_return_reason_id: return_request.customer_return_reason.try(:id),
                                    "invoice_id" => return_request.try(:invoice).try(:id), "invoice_number" => return_request.try(:invoice).invoice_number, "sku" => invoice_inventory_detail.try(:client_sku_master).try(:code),
                                    "packaging_status" => "Not Packed", "status" => inventory_pending_approval_status.try(:original_code), "grade" => inv_grade_not_tested.try(:original_code),"store_grading_date" => Time.now.to_s , "store_inwarding_date" => Time.now.to_s}
          inventory = Inventory.new(details: inventory_detail_hash.merge!(invoice_inventory_details), distribution_center_id: return_request.try(:invoice).distribution_center_id, client_id: return_request.try(:invoice).client_id, user: user , tag_number: tag_number, is_putaway_inwarded: false)            
          inventory.inventory_statuses.build(status_id: inventory_pending_approval_status.try(:id), distribution_center_id: return_request.try(:invoice).distribution_center_id, details: invoice_inventory_detail.details, is_active: true, user: user)
          inventory.inventory_grading_details.build(grade_id: inv_grade_not_tested.try(:id), distribution_center_id: invoice.distribution_center_id, details: inventory_grading_hash.merge!(invoice_inventory_detail.details), is_active: true, user: user)
          if inventory.save              
            created_inventory = inventory
            invoice_inventory_detail.update(return_quantity: (invoice_inventory_detail.return_quantity + selected_inventory["return_quantity"]))          
          end
    
      end
      status = true
      return_request_details = {"total_inventories" => total_inventories, "invoice_number" => return_request.try(:invoice).try(:invoice_number),
                                "customer_return_reason" => return_request.try(:customer_return_reason).try(:name)}
      return_request.update(details: return_request_details)
    end # Transaciton end
   
    if status == true
      return true, return_request.request_number,created_inventory.id, { disposition: "Send to Factory", inventories_count: total_inventories, invoice_number: return_request.try(:invoice).try(:invoice_number), inventories: inventories.collect(&:details).map {|c| c["product_code_sku"]}},inv_grade_not_tested.original_code
    else
      return false, {error: "Error in creating inventories"}
    end
  end
    
end