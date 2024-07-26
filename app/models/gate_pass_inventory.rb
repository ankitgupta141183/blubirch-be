class GatePassInventory < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :user, optional: true
  belongs_to :gate_pass, optional: true
  belongs_to :client_category, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :gate_pass_inventory_status, class_name: "LookupValue", foreign_key: :status_id

  validates :item_number, :sku_code, :item_description, :quantity, :scan_id, presence: true

  has_many :inventories
  has_many :order_management_items
  # has_many :gate_pass, through: :inventories

  # serialize :sku_eans, Array

  def create_inventory_data(param, user, documents)
    # ActiveRecord::Base.transaction do
      inv_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
      
      client_category =  self.client_category

      details_hash = Hash.new 
      client_category_hash = Hash.new
      grading_hash = Hash.new

      client_category.ancestors.each_with_index {|k, i| client_category_hash["category_l#{i+1}"] = k.name}
      client_category_hash["category_l#{client_category.ancestors.size+1}"] = client_category.name

      disposition = param["manual_disposition"].present? ? param["manual_disposition"] : param["disposition"]  

      details_hash = {"stn_number" => self.gate_pass.client_gatepass_number,
                      "dispatch_date" => self.gate_pass.dispatch_date.strftime("%Y-%m-%d %R"), 
                      "inward_grading_time" => Time.now.to_s,
                      "inward_user_id" => user.id,
                      "inward_user_name" => user.username,
                      "source_code" => self.gate_pass.source_code,
                      "destination_code" => self.gate_pass.destination_code,
                      "processed_grading_result" => param["processed_grading_result"],
                      "inwarding_disposition" => param["disposition"],
                      "brand" => self.brand,
                      "client_sku_master_id" => self.client_sku_master_id.try(:to_s),
                      "ean" => self.ean,
                      "merchandise_category" => self.merchandise_category,
                      "merch_cat_desc" => self.merch_cat_desc,
                      "line_item" => self.line_item,
                      "document_type" => self.document_type,
                      "site_name" => self.site_name,
                      "consolidated_gi" => self.consolidated_gi,
                      "sto_date" => self.sto_date,
                      "group" => self.group,
                      "group_code" => self.group_code,
                      "own_label" => (self.details.present? ? self.details["own_label"] : nil) }

      details_hash["manual_disposition"] = param["manual_disposition"] if param["manual_disposition"].present?
      details_hash["work_flow_name"] = param["work_flow_name"] if param["work_flow_name"].present?

      if param["policy_type"].present?
        policy = LookupValue.where(code: param["policy_type"]).first
        details_hash["policy_id"] = policy.id
        details_hash["policy_type"] = policy.original_code
      end

      grading_hash = {"processed_grading_result" => param["processed_grading_result"],
                      "final_grading_result" => param["final_grading_result"],
                      "user_id" => user.id, "user_name" => user.username}

      final_details_hash = details_hash.deep_merge!(client_category_hash)
      
      inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first 

      inventory = Inventory.new(user_id: user.id, gate_pass_id: self.gate_pass_id, distribution_center_id: self.distribution_center_id,
                                client_id: self.client_id, sku_code: self.sku_code, item_description: self.item_description, 
                                quantity: 1, gate_pass_inventory_id: self.id ,item_price: self.map, tag_number: param["tag_number"],
                                client_tag_number: param["tag_number"], toat_number: param["toat_number"], disposition: disposition,
                                grade: param["grade"], return_reason: param['return_reason'], details: final_details_hash,
                                serial_number: (param["serial_number"].present? ? param["serial_number"] : nil),
                                serial_number_2: (param["serial_number_2"].present? ? param["serial_number_2"] : nil), 
                                sr_number: (param["sr_number"].present? ? param["sr_number"] : nil), status: inventory_status_warehouse_pending_grn.original_code,
                                status_id: inventory_status_warehouse_pending_grn.try(:id), client_category_id: client_category.id, is_forward: false, is_putaway_inwarded: false)

      inventory.inventory_statuses.build(status_id: inventory_status_warehouse_pending_grn.id, user_id: user.id, distribution_center_id: inventory.distribution_center_id,
                                         details: {"user_id" => user.id, "user_name" => user.username})

      grade_id = LookupValue.where(original_code: inventory.grade).last.try(:id)
     
      if grade_id.nil? 
        not_tested_grade = LookupValue.where(code: Rails.application.credentials.inventory_grade_not_tested).last
        grade_id = not_tested_grade.id
        inventory.grade = not_tested_grade.original_code
      end

      inventory.inventory_grading_details.build(distribution_center_id: inventory.distribution_center_id, user_id: inventory.user_id, details: grading_hash, grade_id: grade_id)

      if documents.present?
        documents.each do |document|
          document_type = LookupValue.where(code: document[1]["code"]).first
          if document[1]['document'].present?
            attachment = inventory.inventory_documents.new(reference_number: document[1]['reference_number'],
                                                           document_name_id: document_type.id )
            attachment.attachment = document[1]['document']
            attachment.save
          else
            inventory.details["return_reason_document_type"] = document[1]["code"]
            inventory.details["document_text"] = document[1]['document_text']
          end
        end
      end

      # Every Time when a gatepass inventory will be inwarded, We will increase its inwarding quantity.

      if inventory.save
        if self.update(inwarded_quantity: self.inwarded_quantity + 1) && self.update_gate_pass_inventory_status
          excess_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
          
          # if gatepass inventory has Excess Status then we will store issue type Excess in inventory. 

          inventory.details["issue_type"] = Rails.application.credentials.issue_type_excess if self.status_id == excess_status.id
          inventory.save
          return true
        else
          return false
        end
      else
        return false, error: "#{inventory.errors.full_messages[0]}"
      end
    # end
  end

  
  def update_inventory_data(param, user, documents, inventory)
    client_category =  self.client_category

    details_hash = Hash.new 
    client_category_hash = Hash.new
    grading_hash = Hash.new
    complete_details_hash = Hash.new 

    client_category.ancestors.each_with_index {|k, i| client_category_hash["category_l#{i+1}"] = k.name}
    client_category_hash["category_l#{client_category.ancestors.size+1}"] = client_category.name

    disposition = param["manual_disposition"].present? ? param["manual_disposition"] : param["disposition"]  

    details_hash = {"processed_grading_result" => param["processed_grading_result"],
                    "inwarding_disposition" => param["disposition"],
                    "inward_grading_time" => Time.now.to_s,
                    "inward_user_id" => user.id,
                    "inward_user_name" => user.username }

    details_hash["manual_disposition"] = param["manual_disposition"] if param["manual_disposition"].present?

    if param["policy_type"].present?
      policy = LookupValue.where(code: param["policy_type"]).first
      details_hash["policy_id"] = policy.id
      details_hash["policy_type"] = policy.original_code
    end

    grading_hash = {"processed_grading_result" => param["processed_grading_result"],
                    "final_grading_result" => param["final_grading_result"],
                    "user_id" => user.id, "user_name" => user.username}

    final_details_hash = details_hash.deep_merge!(client_category_hash)
  
    complete_details_hash = final_details_hash.deep_merge!(inventory.details)

    complete_details_hash.tap{ |hs| hs.delete("issue_type") }

    inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first 

    inventory.update_attributes(disposition: disposition, grade: param["grade"], tag_number: param["tag_number"],
                              client_tag_number: param["tag_number"], toat_number: param["toat_number"], return_reason: param['return_reason'], details: complete_details_hash,
                              serial_number: (param["serial_number"].present? ? param["serial_number"] : nil),
                              serial_number_2: (param["serial_number_2"].present? ? param["serial_number_2"] : nil), 
                              sr_number: (param["sr_number"].present? ? param["sr_number"] : nil), status: inventory_status_warehouse_pending_grn.original_code,
                              status_id: inventory_status_warehouse_pending_grn.try(:id), client_category_id: client_category.id)


    grading_detail = inventory.inventory_grading_details.last
    grading_detail.details["processed_grading_result"] = param["processed_grading_result"]
    grading_detail.details["final_grading_result"] = param["final_grading_result"]
    grading_detail.save

    if documents.present?
      documents.each do |document|
        document_type = LookupValue.where(code: document[1]["code"]).first
        if document[1]['document'].present?
          attachment = inventory.inventory_documents.new(reference_number: document[1]['reference_number'], document_name_id: document_type.id)
          attachment.attachment = document[1]['document']
          attachment.save
        else
          inventory.details["return_reason_document_type"] = document[1]["code"]
          inventory.details["document_text"] = document[1]['document_text']
        end
      end
    end

    # if inventory.disposition.present?
    #   code = 'inventory_status_warehouse_pending_'+ inventory.disposition.downcase
    #   bucket_status =  LookupValue.where("code = ?", Rails.application.credentials.send(code)).first
    #   inventory.inventory_statuses.where(is_active: true).update_all(is_active: false) if inventory.inventory_statuses.present?
    #   inventory.inventory_statuses.create(status_id: bucket_status.id, user_id: user.id, distribution_center_id: inventory.distribution_center_id, 
    #                                       details: {"user_id" => user.id, "user_name" => user.username})
    #   DispositionRule.create_bucket_record(inventory.disposition, inventory)
    # end

    self.update(inwarded_quantity: self.inwarded_quantity + 1)
    if self.update_gate_pass_inventory_status
      return true
    else
      return false
    end
  end


  def update_gate_pass_inventory_status
    
    # Updating gate pass inventory after inwarding.

    if self.inwarded_quantity == self.quantity
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_fully_received).first
      self.update_attributes(status_id: gp_status.id, status: gp_status.original_code)    
    elsif self.inwarded_quantity > self.quantity
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
      self.update_attributes(status_id: gp_status.id, status: gp_status.original_code)  
    elsif self.inwarded_quantity < self.quantity
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_part_received).first
      self.update_attributes(status_id: gp_status.id, status: gp_status.original_code)
    end   
  end


end