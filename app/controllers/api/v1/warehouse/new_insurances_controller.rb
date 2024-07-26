class Api::V1::Warehouse::NewInsurancesController < ApplicationController
  before_action :set_insurance, only: [:show, :update_document, :update_claim_amount]

  # GET api/v1/warehouse/insurances
  def index
    set_pagination_params(params)
    filter_insurances
    @insurances = @insurances.page(@current_page).per(@per_page)
    render json: @insurances, meta: pagination_meta(@insurances)
  end

  def show
    data = @insurance.as_json(only: [:id, :tag_number, :grade, :sku_code, :item_description, :incident_location, :responsible_vendor, :damage_type, :claim_ticket_number, :claim_decision, :approval_ref_number, :approved_amount])
    # TODO: remove later
    data[:incident_date] = format_date(@insurance.created_at.to_date)
    data[:incident_location] = "Warehouse"
    data[:damage_type] = "Handling"
    # data[:incident_date] = format_date(@insurance.incident_date)
    data[:claim_ticket_date] = format_date(@insurance.claim_ticket_date)
    data[:inspection_date] = format_date(@insurance.claim_inspection_date.to_date) rescue ''
    data[:approved_date] = format_date(@insurance.approved_date)
    data[:inspection_report] = {name: @insurance.inspection_report&.file&.filename, url: @insurance.inspection_report_url} if @insurance.inspection_report.present?
    data[:required_documents] = @insurance.get_required_documents
    render json: { insurance: data }
  end
  
  def update_document
    begin
      message = @insurance.update_document(params)
      if @insurance.check_for_pending_claim_ticket?
        @insurance.update!(insurance_status: "pending_claim_ticket")
        @insurance.update_inventory_status("insurance_status_pending_claim_ticket", current_user)
      end
      
      render json: { message: message }
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end
  
  def get_pending_documents
    insurances = get_multiple_records
    all_docs = insurances.map{|i| i.pending_documents }
    pending_documents = Insurance.common_hashes all_docs
    pending_documents = pending_documents.map{|d| {field: d["field"].parameterize.underscore, label: d["field"], data_type: d["data_type"], is_mandatory: d["is_mandatory"]} }
    pending_documents += [{field: "incident_images", label: "Incident Images", data_type: "image", is_mandatory: true, value: []}, {field: "incident_videos", label: "Incident Videos", data_type: "video", is_mandatory: true, value: []}]
    
    render json: { pending_documents: pending_documents }
  end
  
  def bulk_update_docs
    begin
      formatted_doc_hash = get_formatted_params(params)
      insurances = Insurance.where("id in (#{formatted_doc_hash["ids"].to_s})")
      insurances.each do |insurance|
        formatted_doc_hash["documents"].each do |document|
          document = document.symbolize_keys
          insurance.update_document(document)
        end
        if insurance.check_for_pending_claim_ticket?
          insurance.update!(insurance_status: "pending_claim_ticket")
          insurance.update_inventory_status("insurance_status_pending_claim_ticket", current_user)
        end
      end
      
      items_moved_to_pending_claim = insurances.insurance_status_pending_claim_ticket.count
      if items_moved_to_pending_claim > 0
        message = "#{items_moved_to_pending_claim} item moved to Pending Claim Ticket."
      else
        message = "Documents updated successfully."
      end
      render json: { message: message }
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
    end
  end

  def update_claim_ticket
    insurances = get_multiple_records
    
    raise CustomErrors.new "Please fill the details." if (params[:claim_ticket_date].blank? || params[:claim_ticket_number].blank?)
    insurances.each do |insurance|
      insurance.claim_ticket_date = params[:claim_ticket_date]
      insurance.claim_ticket_number = params[:claim_ticket_number]
      insurance.insurance_status = "pending_inspection"
      insurance.save!
      insurance.update_inventory_status("insurance_status_pending_inspection", current_user)
    end
    
    render json: { message: "#{insurances.count} Item moved to Pending Inspection" }
  end
  
  def update_claim_amount
    raise CustomErrors.new "Amount can not be blank." if (params[:claim_amount].blank?)
    raise CustomErrors.new "Claim Amount cannot be zero or negative." if params[:claim_amount].to_f <= 0
    @insurance.update!(claim_amount: params[:claim_amount])
    
    render json: { message: "Claim amount updated successfully." }
  end
  
  def update_inspection_details
    insurances = Insurance.where("id in (#{params[:ids].to_s})")
    # insurances = Insurance.where(id: JSON.parse(params[:ids].to_s))
    raise CustomErrors.new "Invalid ID." if insurances.blank?
    
    raise CustomErrors.new "Please fill the details." if (params[:claim_inspection_date].blank? || params[:inspection_report].blank?)
    validate_file_format(params[:inspection_report], "Inspection Report")
    insurances.each do |insurance|
      insurance.update!(claim_inspection_date: params[:claim_inspection_date], inspection_report: params[:inspection_report], insurance_status: "pending_decision")
      insurance.update_inventory_status("insurance_status_pending_decision", current_user)
    end
    
    render json: { message: "#{insurances.count} Item moved to Pending Decision" }
  end
  
  def get_claim_decisions
    #& Setting approved amount as 0
    approved_amount = 0
    
    #& Getting insurances data based on id
    insurances = Insurance.where("id in (#{params[:ids].to_s})")

    #& Getting total claim amount from the selected insurances
    approved_amount = insurances.pluck(:claim_amount).compact.sum if insurances.present?
    
    #& if we are selecting multiple items in pending decision, then we are ignoreing 'partially_approved' as claim decisions
    if params[:has_multiple_items] == "true" || params[:has_multiple_items] == true 
      claim_decisions = Insurance.claim_decisions.except("partially_approved").keys.map{|i| {id: i, name: i.titleize} }
    else
      claim_decisions = Insurance.claim_decisions.keys.map{|i| {id: i, name: i.titleize} }
    end

    salvage_actions = [{id: "liquidate", name: "Liquidate"}, {id: "no_action", name: "No Action"}]

    render json: {claim_decisions: claim_decisions, salvage_actions: salvage_actions, approved_amount: approved_amount}
  end
  
  def update_approval_details
    Insurance.transaction do
      insurances = get_multiple_records
      
      raise CustomErrors.new "Invalid Claim Decision" if params[:claim_decision].blank?
      raise CustomErrors.new "Approval Reference Number can not be blank." if params[:approval_ref_number].blank?
      raise CustomErrors.new "Approval Amount cannot be negative" if params[:approved_amount].present? && params[:approved_amount].to_f.negative?

      #& We cannot accept multiple records for partially approved claim decision
      if insurances.present? && insurances.count > 1 && params[:claim_decision].present? && params[:claim_decision] == "partially_approved"
        raise CustomErrors.new "We cannot accept multiple records for partially approved claim decision."
      end

      insurances.each do |insurance|
        insurance.claim_decision =  params[:claim_decision]
        insurance.approval_ref_number = params[:approval_ref_number]

        #& Setting approved amount based on the selected claim decision
        insurance.approved_amount = insurance.claim_amount.to_f if params[:claim_decision] == "approved"
        insurance.approved_amount = params[:approved_amount].to_f if params[:claim_decision] == "partially_approved"
        insurance.approved_amount = 0.0 if params[:claim_decision] == "rejected"
        insurance.net_recovery = insurance.approved_amount
        insurance.recovery_percent = insurance.get_recovery_percent
        
        insurance.save!
      end

      if params[:salvage_action] == "liquidate"
        insurances.each do |insurance|
          disposition = "Liquidation"
          insurance.set_disposition(disposition, current_user)
        end
        message = "#{insurances.count} item moved to Liquidation successfully."
      else
        insurances.each do |insurance|
          insurance.update(insurance_status: "pending_disposition")
          insurance.update_inventory_status("insurance_status_pending_disposition", current_user)
        end
        message = "#{insurances.count} Item moved to Pending Disposition"
      end

      if (params[:claim_decision] == "approved" || params[:claim_decision] == "partially_approved")
        claim_data = insurances.map{ |insurance| 
          { inventory_id: insurance.inventory_id, stage_name: :insurance_claim, vendor_code: insurance.get_vendor_code, note_type: :credit, approval_reference_number: params[:approval_ref_number], claim_amount: insurance.claim_amount, tab_status: :recovery }
        }
        ThirdPartyClaim.create_thrid_party_claim(claim_data)
      end
      
      render json: { message: message }
    end
  end

  def get_dispositions
    dispositions = ["Repair", "Markdown", "Liquidation", "Restock"].map{|d| {id: d, code: d} }
    render json: { dispositions: dispositions }
  end
  
  def update_disposition
    insurances = Insurance.includes(:inventory).where(id: params[:ids], insurance_status: "pending_disposition")
    raise CustomErrors.new "Invalid ID." if insurances.blank?
    raise CustomErrors.new "Disposition can not be blank!" if params[:disposition].blank?

    insurances.each do |insurance|
      begin
        insurance.assigned_disposition = params[:disposition]
        insurance.assigned_id = current_user.id
        insurance.save!
      rescue => exc
        raise CustomErrors.new exc
      end

      inventory = insurance.inventory
      #& It will create approval request for current insurance record
      details = { 
        tag_number: insurance.tag_number,
        article_number: insurance.sku_code,
        brand: inventory.details['brand'],
        mrp: inventory.item_price,
        description: inventory.item_description,
        requested_by: current_user.full_name,
        grade: insurance.grade,
        inventory_created_date: CommonUtils.format_date(inventory.created_at.to_date),
        requested_date: CommonUtils.format_date(Date.current.to_date),
        requested_disposition: params[:disposition],
        distribution_center: insurance.distribution_center&.name,
        subject: "Approval required for Disposition of #{insurance.sku_code} in RPA:#{insurance.distribution_center&.name}",
        rims_url: get_host,
        rule_engine_type: get_rule_engine_type
      }
      ApprovalRequest.create_approval_request(object: insurance, request_type: 'insurance', request_amount: insurance.approved_amount, details: details)
    end
     
    render json: { message: "Admin successfully notified for Disposition Approval" }
  end
  
  def set_disposition
    begin
      ActiveRecord::Base.transaction do
        insurances = Insurance.where(id: params[:ids], insurance_status: "pending_disposition").includes(:inventory)
        raise CustomErrors.new "Invalid ID." if insurances.blank?
        insurances_count = insurances.count

        if params[:disposition_action] == "reject"
          disposition = params[:disposition]
          raise CustomErrors.new "Disposition can not be blank!" if disposition.blank?
        else
          disposition = nil
        end
        assigned_disposition_data = []
        insurances.each do |insurance|
          assigned_disposition = disposition || insurance.assigned_disposition
          assigned_disposition_data << assigned_disposition
          insurance.set_disposition(assigned_disposition, current_user)
          # if (params[:disposition_action] == "reject" and insurance.assigner.present?)
          #   details = { email: insurance.assigner.email, base_url: get_host, tag_number: insurance.tag_number }
          #   InsuranceRejectMailerWorker.perform_async(details)
          # end
        end
        render json: { message: "#{insurances_count} item is moved to #{assigned_disposition_data.join(',')} successfully." }
      end
    rescue Exception => message
      render json: { error: message.to_s }, status: 500
      return
    end
  end


  private
  
  def set_insurance
    @insurance = Insurance.find_by(id: params[:id])
  end
  
  def filter_insurances
    @insurances = Insurance.includes(:inventory).where(insurance_status: params[:status], is_active: true).order('insurances.updated_at desc')
    dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.select(:id)
    @insurances = @insurances.where(distribution_center_id: dc_ids)
    
    if params[:status] == "pending_disposition"
      user_roles = current_user.roles.pluck(:code)
      if user_roles.include?('default_user')
        @insurances = @insurances.where(assigned_disposition: nil)
      elsif user_roles.include?('central_admin')
        @insurances = @insurances.where.not(assigned_disposition: nil)
      end
    end
    # @insurances = @insurances.where("inventories.is_putaway_inwarded IS NOT false")
    if params[:tag_number].present?
      tag_numbers = params[:tag_number].split(',').collect(&:strip).flatten
      @insurances = @insurances.where(tag_number: tag_numbers)
    end
    @insurances = @insurances.where(incident_location: params[:incident_location]) if params[:incident_location].present?
    @insurances = @insurances.where(incident_date: params[:incident_date]) if params[:incident_date].present?
    @insurances = @insurances.where(damage_type: params[:damage_type]) if params[:damage_type].present?
    @insurances = @insurances.where(sku_code: params[:sku_code]) if params[:sku_code].present?
  end
  
  def get_multiple_records
    insurances = Insurance.where(id: params[:ids])
    raise CustomErrors.new "Invalid ID." if insurances.blank?
    insurances
  end
  
  def notify_admin_users(insurances)
    # TODO: create Insurance head role and update here
    # admin = Role.find_by(code: "central_admin")
    # admin_emails = admin.users.pluck(:email).compact
    # insurances.each do |insurance|
    #   details = { email: admin_emails, base_url: get_host, tag_number: insurance.tag_number }
    #   InsuranceAdminMailerWorker.perform_async(details)
    # end
  end
  
  #? FROM
  #^ {
  #^   "ids"=>"4828,4829",
  #^   "file"=>{
  #^       "0"=>#<ActionDispatch: :Http: :UploadedFile: 0x000055e4199456a8 @tempfile=#<Tempfile:/tmp/RackMultipart20230505-8898-mddcsc.mp4>, @original_filename="sample-5s.mp4", @content_type="video/mp4", @headers="Content-Disposition: form-data; name=\"file[0]\"; filename=\"sample-5s.mp4\"\r\nContent-Type: video/mp4\r\n">,
  #^       "1"=>#<ActionDispatch: :Http: :UploadedFile: 0x000055e419945608 @tempfile=#<Tempfile:/tmp/RackMultipart20230505-8898-t1yvvt.png>, @original_filename="Screenshot from 2023-04-07 16-33-39.png", @content_type="image/png", @headers="Content-Disposition: form-data; name=\"file[1]\"; filename=\"Screenshot from 2023-04-07 16-33-39.png\"\r\nContent-Type: image/png\r\n">
  #^   },
  #^   "field"=>{
  #^       "0"=>"this_is_for_test",
  #^       "1"=>"namesake"
  #^   },
  #^   "label"=>{
  #^       "0"=>"this is for test",
  #^       "1"=>"namesake"
  #^   },
  #^   "data_type"=>{
  #^       "0"=>"video",
  #^       "1"=>"info"
  #^   },
  #^   "value"=>{
  #^       "0"=>"",
  #^       "1"=>"This is for test"
  #^   }
  #^ }
  #? TO
  #^ {
  #^   "ids" => "4828,4829",
  #^   "documents" => [
  #^     [0] {
  #^              :file => #<ActionDispatch: :Http: :UploadedFile: 0x000055e4199456a8 @tempfile=#<Tempfile:/tmp/RackMultipart20230505-8898-mddcsc.mp4>, @original_filename="sample-5s.mp4", @content_type="video/mp4", @headers="Content-Disposition: form-data; name=\"file[0]\"; filename=\"sample-5s.mp4\"\r\nContent-Type: video/mp4\r\n">,
  #^             :field => "this_is_for_test",
  #^             :label => "this is for test",
  #^         :data_type => "video",
  #^             :value => ""
  #^     },
  #^     [1] {
  #^              :file => "",
  #^             :field => "namesake",
  #^             :label => "namesake",
  #^         :data_type => "info",
  #^             :value => "This is for test"
  #^     }
  #^   ]
  #^ }
  def get_formatted_params params
    #data = []
    #params[:field].size.times do |i|
    #  data << {field: params[:field][i], label: params[:label][i], data_type: params[:data_type][i], file: params[:file][i], value: params[:value][i]}
    #end
    #data

    final_hash = {}
    new_data = []
    
    params.except("ids", "action", "controller").each do |key, values_arr|

      index = 0
      values_arr.each do |hash_d|
        
        if new_data[index].present?
          new_data[index].merge!({key => hash_d[1]})
        else
          new_data[index] = {}
          new_data[index][key] = hash_d[1]
        end
        index += 1
      
      end  
    end
    
    final_hash["ids"] = params[:ids]
    final_hash["documents"] = new_data
    final_hash
  end
  
  def validate_file_format(file, file_type)
    ext = File.extname(file.original_filename)
    file_formats = Insurance::FILE_FORMATS
    
    raise CustomErrors.new "Invalid file format for #{file_type}" unless file_formats.include? ext
  end
  
end
