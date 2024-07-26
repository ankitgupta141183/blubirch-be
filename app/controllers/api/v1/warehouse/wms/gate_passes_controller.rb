class Api::V1::Warehouse::Wms::GatePassesController < ApplicationController
  before_action :set_gate_pass, only: [:show, :update, :destroy]
  # GET /gate_passes
  def index
    set_pagination_params(params)
    status =  LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
    distribution_centers_ids = current_user.distribution_centers.pluck(:id)
    if params['search'].present?
      @gate_passes = GatePass.where.not(status_id: status.id).where(destination_id: distribution_centers_ids, client_gatepass_number: params['search']).page(@current_page).per(@per_page)
    else
      @gate_passes = GatePass.where.not(status_id: status.id).where(destination_id: distribution_centers_ids).page(@current_page).per(@per_page)
    end
    @gate_passes = @gate_passes.where('updated_at > ?', Date.strptime(params['date'], '%m/%d/%Y')) if params['date'].present?

    if @gate_passes.present?
      render json: @gate_passes, meta: pagination_meta(@gate_passes)
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  # GET /gate_passes/1
  def show
    render json: @gate_pass
  end

  # POST /gate_passes
  def create
    @gate_pass = GatePass.new(gate_pass_params)

    if @gate_pass.save
      render json: @gate_pass, status: :created, location: @gate_pass
    else
      render json: @gate_pass.errors, status: 302
    end
  end

  # PATCH/PUT /gate_passes/1
  def update
    if @gate_pass.update(gate_pass_params)
      render json: @gate_pass
    else
      render json: @gate_pass.errors, status: 302
    end
  end

  # DELETE /gate_passes/1
  def destroy
    @gate_pass.destroy
  end

  def export_inward_visibility_report
    type = 'visiblity'
    if current_user.roles.pluck(:code).include?('site_admin')
      report = Rails.env == 'development' ? nil : ReportStatus.where(distribution_center_ids: current_user.distribution_centers.pluck(:id), report_type: type, created_at: (Time.zone.now - 30.minutes)..(Time.zone.now), status: 'Completed', report_for: 'site_admin').last
    elsif current_user.roles.pluck(:code).include?('central_admin')
      report = Rails.env == 'development' ? nil : ReportStatus.where(report_type: type, created_at: (Time.zone.now - 30.minutes)..(Time.zone.now), status: 'Completed', report_for: 'central_admin').last
    end  
    if report.present?
      #Send Mail with URL
      url = report.details['url']
      timestamp = report.details['completed_at_time'].to_datetime.strftime("%F %I:%M:%S %p")
      ReportMailer.visiblity_email(type ,url, current_user.id, current_user.email, timestamp).deliver_now
      render json: 'Success', status: 200
    elsif !get_report_status(type)
      ReportMailerWorker.perform_async(type, @current_user.id)
      render json: 'Success', status: 200
    else
      render json: {message: "Inward Report Already In Process and will be sent to email #{current_user.email} Shortly", status: 302}
    end
  end

  def export_outward_visibility_report
    type = 'outward'
    if current_user.roles.pluck(:code).include?('central_admin')
      report = Rails.env == 'development' ? nil : ReportStatus.where(report_type: type, latest: true, status: 'Completed', report_for: 'central_admin').last
      #Send Mail
      if report.present?
        url = report.details['url']
        timestamp = report.details['completed_at_time'].to_datetime.strftime("%F %I:%M:%S %p")
        ReportMailer.visiblity_email(type ,url, current_user.id, current_user.email, timestamp).deliver_now
      else
        ReportMailerWorker.perform_async(type, @current_user.id)
      end
      render json: 'Success', status: 200
    else
      ReportMailerWorker.perform_async(type, @current_user.id)
      render json: 'Success', status: 200
    end
  end

  def export_daily_report
    url = Inventory.export_daily_report(params[:daily_report_type])
    render json: {url: url}
  end

  def timeline_report
    type = 'inward'
    report = nil
    if current_user.roles.pluck(:code).include?('central_admin') 
      report = Rails.env == 'development' ? nil : ReportStatus.where(report_type: type, latest: true, status: 'Completed', report_for: 'central_admin').last
      #Send Mail
      if report.present?
        url = report.details['url']
        timestamp = report.details['completed_at_time'].to_datetime.strftime("%F %I:%M:%S %p")
        ReportMailer.visiblity_email(type ,url, current_user.id, current_user.email, timestamp).deliver_now
      else
        ReportMailerWorker.perform_async(type, @current_user.id)
      end
      render json: 'Success', status: 200
    else
      ReportMailerWorker.perform_async(type, @current_user.id)
      render json: 'Success', status: 200
    end
  end

  def client_category_grading_rules
    @client_category_grading_rules = ClientCategoryGradingRule.where(grading_type: 'Warehouse')
    test_rule_ids = @client_category_grading_rules.pluck(:test_rule_id).uniq
    grading_rule_ids = @client_category_grading_rules.pluck(:grading_rule_id).uniq
    @test_rules = TestRule.where(id: test_rule_ids)
    @grading_rules = GradingRule.where(id: grading_rule_ids)
    render json: {grading_rules: @grading_rules.as_json(only: [:id, :rules]), test_rules: @test_rules.as_json(only: [:id, :rules]), client_category_grading_rules: @client_category_grading_rules.as_json(only: [:id, :grading_type, :grading_rule_id, :test_rule_id], include: { client_category: { only: [:id, :name, :code] } })}
  end

  def disposition_rules
    @disposition_rules = DispositionRule.all
    @client_category_mappings = ClientCategoryMapping.all
    @rules = Rule.all
    render json: {disposition_rules: @disposition_rules, client_category_mappings: @client_category_mappings, rules: @rules}
  end

  def update_inwarding_details
    gate_pass = GatePass.where(gatepass_number: params['gatepass_number'])
    params['gatepass_inventories'].each do |inventory|
      gp_inventory = GatePassInventory.find(params['inventory']['id'])
      gp_inventory.update_attributes(inwarded_quantity: inventory['inwarded_quantity'])
    end
  end

  def generate_tag
    @tag_number =  "T-#{SecureRandom.hex(3)}".downcase
    render json: {tag_number: @tag_number}
  end

  def export_pending_grn_inventories
    ids = current_user.distribution_centers.pluck(:id)
    url = Inventory.export(ids)
    render json: {url: url}
  end

  def get_grn_data
    set_pagination_params(params)
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    if params[:search].present?
      @gate_passes = GatePass.includes(:gate_pass_inventories).where(distribution_center_id: ids, status: ['Pending Receipt', 'Open'], is_forward: false).where("client_gatepass_number LIKE ?", "%#{params['search']}%").order('updated_at desc').page(@current_page).per(@per_page)
    else
      @gate_passes = GatePass.includes(:gate_pass_inventories).where(distribution_center_id: ids, status: ['Pending Receipt', 'Open'], is_forward: false).order('updated_at desc').page(@current_page).per(@per_page)
    end
    render json: @gate_passes, meta: pagination_meta(@gate_passes)
  end

  def return_reasons
    @return_reasons = CustomerReturnReason.where(own_label: ( params[:own_label].present? ? params[:own_label] : false) ).order(:position)
    file_type = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    @document_types = file_type.lookup_values.pluck(:code, :original_code)
    grade_key = LookupKey.where(code: "INV_GRADE").last
    @grade_values = grade_key.lookup_values.where.not(original_code: ["Not Tested", "A1"]).pluck(:code, :original_code)
    render json: {return_reasons: @return_reasons.as_json(methods: [:document_types, :input_type, :min_value, :max_value, :is_mandatory]), grade_values: @grade_values}
  end

  def search_sku
    @client_sku = ClientSkuMaster.where('code = ? or ean = ?', params["sku_code"], params["sku_code"])
    render json: @client_sku if @client_sku.present?
    render json: {message: "Not Found", status: 302} if @client_sku.blank?
  end

  def serial_verification
    closed_status_id = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).last.id
    inventories_for_serial_1 = Inventory.where('serial_number = ? or serial_number_2 = ?', params["serial_number"], params["serial_number"]).where(is_forward: false) if params["serial_number"].present? && params["serial_number"] != ""
    inventories_for_serial_2 = Inventory.where('serial_number = ? or serial_number_2 = ?', params["serial_number_2"], params["serial_number_2"]).where(is_forward: false) if params["serial_number_2"].present? && params["serial_number_2"] != ""
    if (inventories_for_serial_1.present? && inventories_for_serial_2.present?) 
      if ( inventories_for_serial_1.last.distribution_center_id == params['distribution_center_id'] || inventories_for_serial_2.last.distribution_center_id == params['distribution_center_id']) 
        render json: {message: "Grading is already done for #{params['serial_number']} and #{params['serial_number_2']}", status: 200}
      elsif ( inventories_for_serial_1.last.status_id != closed_status_id  || inventories_for_serial_2.last.status_id != closed_status_id) 
        render json: {message: "Grading is already done for #{params['serial_number']} and #{params['serial_number_2']}", status: 200}
      else
        render json: {message: "Not Found", status: 204}
      end
    elsif inventories_for_serial_1.present?
      if ( inventories_for_serial_1.last.distribution_center_id == params['distribution_center_id'])
        render json: {message: "Grading is already done for #{params['serial_number']}", status: 200} 
      elsif ( inventories_for_serial_1.last.status_id != closed_status_id) 
        render json: {message: "Grading is already done for #{params['serial_number']}", status: 200}
      else
        render json: {message: "Not Found", status: 204}
      end
    elsif inventories_for_serial_2.present?
      if ( inventories_for_serial_2.last.distribution_center_id == params['distribution_center_id'])
        render json: {message: "Grading is already done for #{params['serial_number_2']}", status: 200}
      elsif ( inventories_for_serial_2.last.status_id != closed_status_id) 
        render json: {message: "Grading is already done for #{params['serial_number_2']}", status: 200}
      else
        render json: {message: "Not Found", status: 204}
      end
    else
      render json: {message: "Not Found", status: 204}      
    end
  end

  def category_rules
    @category = ClientCategoryGradingRule.find_by(client_category_id:params[:id], grading_type: 'Warehouse') rescue nil
     
    if @category.present?
      @test_rule = TestRule.find(@category.test_rule_id) rescue nil
      @grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
    else
      @category_id = ClientCategoryMapping.find_by(client_category_id:params[:id]).category_id rescue nil
      @category = CategoryGradingRule.find_by(category_id:@category_id, grading_type:'Warehouse') rescue nil
      @test_rule = TestRule.find(@category.test_rule_id) rescue nil
      @grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
    end
    @client_category_mapping = ClientCategoryMapping.find_by(client_category_id:params[:id]) rescue nil

    if @test_rule.present?
      render json: {test_rule: @test_rule.rules , grading_rule_id: @grade_rule.id , test_rule_id: @test_rule.id, status: 200}
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  def stn_search
    @gate_passes = GatePass.where("lower(client_gatepass_number) = ?", "#{params['stn_number'].downcase}") if params['stn_number'].present?
    if @gate_passes.present?
      if @gate_passes.pluck(:destination_id).include?(current_user.distribution_centers.last.id)
        render json: @gate_passes
      else
        # render json: { gate_passes: @gate_passes, gate_pass_inventories: @gate_passes.last.gate_pass_inventories, message: "Different Mismatch" }
        render json: @gate_passes, meta: meta_message_attribute("Destination Mismatch")
      end
    else
      render json: {message: "Not Found", status: 302}
    end
  end
  

  def proceed_grn
    begin
      ActiveRecord::Base.transaction do

        gate_pass = GatePass.includes(:inventories, :gate_pass_inventories).where("lower(client_gatepass_number) = ?", params["stn_number"].downcase).first
        inventories = gate_pass.inventories.opened
        if gate_pass.details == nil
          gate_pass.details = {}
          gate_pass.save
        end
        flag = false
        gate_pass.update_details({"grn_submitted_date" => Time.now.to_datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ'), "grn_submitted_user_id" => current_user.id,
                                  "grn_submitted_user_name" => current_user.username})

        gate_pass.gate_pass_inventories.each do |gate_pass_inventory|
        
          pending_grn_inventories = gate_pass_inventory.inventories.where("inventories.details ->> 'issue_type' = ?" , Rails.application.credentials.issue_type_in_transit)
          if pending_grn_inventories.blank?
            quantity_difference = gate_pass_inventory.quantity - gate_pass_inventory.inwarded_quantity
            if quantity_difference > 0
              

              # Now Here comes one condition.

              # Suppose user has one gatepass_inventory with quantity 8 and inwarded quantity 0.
              # Now He inwarded 5 items out of 8 of that gatepass_inventory and click on proceed to GRN
              # Here, You will see that we are creating New Inventories with disposition nil, grade "Not Tested" and serial number "N/A".
              # Number of new inventory created will be (inwarded quantity - quantity)

              quantity_difference.times do
                
                inventory_status_warehouse_pending_grn = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first 

                details_hash = Hash.new
                client_category_hash = Hash.new
                client_category = gate_pass_inventory.client_category

                client_category.ancestors.each_with_index {|k, i| client_category_hash["category_l#{i+1}"] = k.name}
                client_category_hash["category_l#{client_category.ancestors.size+1}"] = client_category.name

                gate_pass_inventory.details["proceed_to_grn_without_grading"] = true
                gate_pass_inventory.save

                last_inventory_graded_date = inventories.try(:last).present? ? inventories.try(:last).try(:details)["inward_grading_time"] : Time.now.to_s
                details_hash =  { "stn_number" => gate_pass_inventory.gate_pass.client_gatepass_number,
                                  "dispatch_date" => gate_pass_inventory.gate_pass.dispatch_date.strftime("%Y-%m-%d %R"), 
                                  # "grn_submitted_date" => Time.now.to_s,
                                  # "grn_submitted_user_id" => current_user.id,
                                  # "grn_submitted_user_name" => current_user.username,
                                  "client_category_id" => gate_pass_inventory.client_category_id,
                                  "brand" => gate_pass_inventory.brand,
                                  "issue_type" => Rails.application.credentials.issue_type_in_transit,
                                  "inward_grading_time" => last_inventory_graded_date,
                                  "inward_user_id" => current_user.id,
                                  "inward_user_name" => current_user.username,
                                  "source_code" => gate_pass.source_code,
                                  "destination_code" => gate_pass.destination_code,
                                  "client_sku_master_id" => gate_pass_inventory.client_sku_master_id.try(:to_s),
                                  "ean" => gate_pass_inventory.ean,
                                  "merchandise_category" => gate_pass_inventory.merchandise_category,
                                  "merch_cat_desc" => gate_pass_inventory.merch_cat_desc,
                                  "line_item" => gate_pass_inventory.line_item,
                                  "document_type" => gate_pass_inventory.document_type,
                                  "site_name" => gate_pass_inventory.site_name,
                                  "consolidated_gi" => gate_pass_inventory.consolidated_gi,
                                  "sto_date" => gate_pass_inventory.sto_date,
                                  "group" => gate_pass_inventory.group,
                                  "group_code" => gate_pass_inventory.group_code,
                                  "own_label" => gate_pass_inventory.details.present? ? gate_pass_inventory.details["own_label"] : "N/A"
                                }

                final_details_hash = details_hash.deep_merge!(client_category_hash)
                
                tag_number =  "d_#{SecureRandom.hex(3)}"
                inv = Inventory.find_by(tag_number: tag_number)
                if inv.present?
                  tag_number = "d_#{SecureRandom.hex(3)}"
                end
                inventory = Inventory.new(tag_number: tag_number ,user: current_user, gate_pass_inventory: gate_pass_inventory, gate_pass: gate_pass_inventory.gate_pass, distribution_center_id: gate_pass_inventory.distribution_center_id,
                                          client_id: gate_pass_inventory.client_id, sku_code: gate_pass_inventory.sku_code, item_description: gate_pass_inventory.item_description,
                                          quantity: 1, grade: "Not Tested", item_price: gate_pass_inventory.map,
                                          details: final_details_hash, status: inventory_status_warehouse_pending_grn.try(:original_code),
                                          status_id: inventory_status_warehouse_pending_grn.try(:id), client_category_id: client_category.try(:id), is_forward: false, is_putaway_inwarded: false)
                inventory.inventory_statuses.build(status_id: inventory_status_warehouse_pending_grn.id, user_id: current_user.id,
                                                   distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})

                grade_id = LookupValue.where(code: Rails.application.credentials.inventory_grade_not_tested).last.id
                
                inventory.inventory_grading_details.build(distribution_center_id: inventory.distribution_center_id, user_id: inventory.user_id, details: final_details_hash, grade_id: grade_id)
                inventory.save
              end
            end
          end
        end

        inventories = gate_pass.inventories.opened.reload

        if inventories.present?
          inventories.each do |inventory|
            if !inventory.disposition.nil?
              if inventory.details["grn_submitted_date"].blank?
                flag = true
                inventory.update_details({"grn_submitted_date" => Time.now.to_datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
                                      "grn_submitted_user_id" => current_user.id, "grn_submitted_user_name" => current_user.username})
              end
            end
          end
          render json: {message: "GRN Proceed Sucessfully", status: 200} if flag == true
          render json: {message: "No Inventories are there to proceed", status: 302} if flag == false
        else
          render json: {message: "Inventories not inwarded for this gate pass", status: 302}
        end
      end
    rescue
     render json: {message: "Server Error", status: 302}
    end
  end

  def update_grn
    begin
      ActiveRecord::Base.transaction do
        gate_pass = GatePass.includes(:gate_pass_inventories, inventories: [:inventory_statuses]).where("lower(client_gatepass_number) = ?", params["stn_number"].downcase).first
        inventories = gate_pass.inventories.opened
        inventory_status_warehouse_pending_issue_resolution = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first

        gate_pass.details = {"grn_submitted_date" => Time.now.to_datetime.strftime('%Y-%m-%dT%H:%M:%S.%LZ'), "grn_submitted_user_id" => current_user.id, "grn_submitted_user_name" => current_user.username} unless gate_pass.details
        gate_pass.update_details({"grn_number" => params["grn_number"]}) if gate_pass.details["grn_number"].blank?

        flag = false

        if inventories.present?
          inventories.each do |inventory|
            details_hash = { "grn_received_time" => Time.now.to_s, "grn_received_user_id" => current_user.id, "grn_received_user_name" => current_user.username, "source_code" => gate_pass.source_code, "destination_code" => gate_pass.destination_code }

            if (inventory.disposition.present?) && inventory.details["grn_number"].blank? && (inventory.details["issue_type"] == nil || inventory.details["issue_type"] == Rails.application.credentials.issue_type_excess)
              flag = true
              details_hash.merge!({"grn_number" => params["grn_number"]})
            end

            final_details_hash = inventory.details.deep_merge!(details_hash)
            inventory.update(details: final_details_hash)

            if [Rails.application.credentials.issue_type_in_transit, Rails.application.credentials.issue_type_excess].include?(inventory.details["issue_type"])
              inventory.update(status_id: inventory_status_warehouse_pending_issue_resolution.id, status: inventory_status_warehouse_pending_issue_resolution.try(:original_code), details: final_details_hash)
              inventory.inventory_statuses.where(is_active: true).update_all(is_active: false) if inventory.inventory_statuses.present?
              inventory.inventory_statuses.create(status_id: inventory_status_warehouse_pending_issue_resolution.id, user_id: current_user.id, distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})
            end

            if inventory.details["issue_type"].blank? && inventory.disposition.present? && inventory.get_current_bucket.blank?
              bucket_code = if inventory.disposition == "E-Waste"
                Rails.application.credentials.inventory_status_warehouse_pending_e_waste
              elsif inventory.disposition == "Pending Transfer Out"
                Rails.application.credentials.inventory_status_warehouse_pending_markdown
              elsif inventory.disposition == "RTV"
                Rails.application.credentials.inventory_status_warehouse_pending_brand_call_log
              else
                code = 'inventory_status_warehouse_pending_'+ inventory.disposition.try(:downcase).try(:parameterize).try(:underscore)
                Rails.application.credentials.send(code)
              end
              bucket_status = LookupValue.find_by_code(bucket_code)

              inventory.inventory_statuses.where(is_active: true).update_all(is_active: false) if inventory.inventory_statuses.present?
              inventory.inventory_statuses.create(status_id: bucket_status.id, user_id: current_user.id, distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})

              DispositionRule.create_bucket_record(inventory.disposition, inventory, "Inward", current_user.id)
              
              inventory.update_inward_putaway!
            end
          end
          gate_pass.update_status
          render json: {message: "GRN Updated Sucessfully", status: 200} if flag == true
          render json: {message: "GRN Already Updated", status: 302} if flag == false
        else
          render json: {message: "Inventories not inwarded for this gate pass", status: 302}
        end
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

  def calculate_grade
    param = JSON.parse(params["grading_data"])
    final_grading_result = param["final_grading_result"]
    if param['gatepass_inventory_id'] == 0
      gp_inventory = GatePassInventory.where(sku_code: param["sku_code"]).last
      if (gp_inventory.present?) && (gp_inventory.quantity > 0)
        render json: {message: "Incorrect Data Passed", status: 302}
        return
      else
        client_sku = ClientSkuMaster.where(code: param["sku_code"]).last
        gatepass = GatePass.where(client_gatepass_number: param["client_gate_pass_number"]).last
        status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
        gate_pass_inventory = gatepass.gate_pass_inventories.new(distribution_center_id: gatepass.distribution_center_id, client_id: gatepass.client_id,
           ean: client_sku.ean, user_id: gatepass.user_id, sku_code: param["sku_code"], item_description: "",
           quantity: 0, status: status.original_code, status_id: status.id, map: client_sku.mrp, client_category_id: client_sku.client_category_id,
           client_category_name: client_sku.client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0)

        gate_pass_inventory.save
      end
    else
      gate_pass_inventory = GatePassInventory.where(id: param['gatepass_inventory_id']).last
    end

    client_category_id = param["client_category_id"].present? ? param["client_category_id"] : gate_pass_inventory.client_category_id 

    grn_status = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_grn).first 
    user = @current_user

    
    if gate_pass_inventory.present?
      inv_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
      inventory = Inventory.where("inventories.details ->> 'sku_code' = ? AND inventories.details ->> 'stn_number' = ? AND inventories.grade = ? AND inventories.serial_number = ?" , param["sku_code"], param["client_gate_pass_number"], "Not Tested", "N/A").last
      if (inventory.present?) && (inventory.inventory_statuses.last.id == inv_status.id)
        # inventory.details["issue_type"] = "Excess" 
        # inventory.save
      else
        inventory = Inventory.new(user_id: user.id, gate_pass_id: gate_pass_inventory.gate_pass_id, is_putaway_inwarded: false)
        inventory.distribution_center_id = gate_pass_inventory.distribution_center_id
        inventory.client_id = gate_pass_inventory.client_id
        inventory.sku_code = gate_pass_inventory.sku_code
        inventory.item_description = gate_pass_inventory.item_description
        inventory.quantity = gate_pass_inventory.quantity
        inventory.serial_number = param['serial_number'].present? ? param['serial_number'] : "N/A" 

        category_l1 = ""
        category_l2 = ""
        ClientCategory.find(client_category_id).ancestors.each_with_index do |cat, index|
          if index == 0
            category_l1 = cat.name 
          end
          if index == 1
            category_l2 = cat.name 
          end
        end
        inventory.item_price = gate_pass_inventory.map
        
        return_reason = param['return_reason'].present? ? param['return_reason'] : "N/A" 
        inventory.return_reason = return_reason
        inventory.details = {"stn_number" => gate_pass_inventory.gate_pass.client_gatepass_number,
          # "dispatch_date" => param["dispatch_date"],
          "dispatch_date" => gate_pass_inventory.gate_pass.dispatch_date.strftime("%Y-%m-%d %R"), 
          "inward_grading_time" => Time.now.to_s,
          "inward_user_id" => user.id,
          "inward_user_name" => user.full_name,
          "return_reason" => return_reason,
          "client_category_id" => gate_pass_inventory.client_category_id,

          "category_l1" => category_l1, 
          "category_l2" => category_l2,

          "brand" => gate_pass_inventory.brand,
          "sku_code" => gate_pass_inventory.sku_code
        }

        inventory.details["issue_type"] == Rails.application.credentials.issue_type_excess if gate_pass_inventory.status == "Excess Received"

        if inventory.save  #Create documents for inventories
          inventory.inventory_statuses.create(status_id: grn_status.id, user_id: current_user.id, distribution_center_id: inventory.distribution_center_id)
          if params[:documents].present?
            params[:documents].each do |document|
              attachment = inventory.inventory_documents.new(reference_number: document[1]['reference_number'])
              attachment.attachment = document[1]['document']
              attachment.save
            end
          end
        end
      end
    end
      

    processed_grading_result = {}
    grading_type = params[:grading_type].present? ? params[:grading_type] : "Warehouse"
    @category = ClientCategoryGradingRule.find_by(client_category_id: client_category_id,grading_type: grading_type)
    if !@category.present?
      @category_id = ClientCategoryMapping.find_by(client_category_id: client_category_id).category_id rescue nil

      @category = CategoryGradingRule.find_by(category_id:@category_id) rescue nil
    end
    grade_rule = GradingRule.find(@category.grading_rule_id).rules["grade_rules"]
    grade_precedence = GradingRule.find(@category.grading_rule_id).rules["grade_precedence"]
    test_rule = TestRule.find(@category.test_rule_id)
    final_grade = ""
    final_disposition = ""

    test_precedence = test_rule.rules

    final_grading_result.each do |key,value|

      max = -1
      maxKey = ""

      if test_precedence["#{key}_precedence"].present?
        temp = final_grading_result[key]
       
        final_grading_result[key].each do |res|
          if !test_precedence["#{key}_precedence"][res["output"]].nil?
            if  res["output"] != "" && test_precedence["#{key}_precedence"][res["output"]] > max
              max = test_precedence["#{key}_precedence"][res["output"]]
              maxKey = res["output"]
            end
          end
        end
        processed_grading_result[key] = maxKey
      else
        processed_grading_result[key] = value[0]["value"]       
      end
    end

    processed_grading_result.each do |key,value|
      if processed_grading_result[key] == ""
        processed_grading_result[key] = "NA"
      end
    end
    #creation of hash2 ends

    #grading begins
    
    flag = 0 
    grade_obj = {}
    test_group_obj = {}
    grade_arr = []
    max = -1
    maxKey = "" 

    grade_rule.each do |gr|
      grade_obj = gr
      flag = 1      

      if grade_obj["test_groups"].present?
        grade_obj["test_groups"].each do |tg|
          test_group_obj = tg
          if !processed_grading_result[test_group_obj["test"]].present?
            processed_grading_result[test_group_obj["test"]] = "NA"
          end
          if !test_group_obj["answers"].include?(processed_grading_result[test_group_obj["test"]])
            flag = -1
            break 
          end
        end
      end
      if flag == 1 && grade_obj["grade"] != "End"
        grade_arr << grade_obj["grade"]
      end
    end

    grade_arr.each do |ga|
      if grade_precedence[ga].to_i > max
        max = grade_precedence[ga].to_i
        maxKey = ga
      end
    end

    final_grade = maxKey

    # rule = ClientDispositionRule.find_by(client_category_id:client_category_id).rule rescue nil
    # if !rule.present?
    #   @temp_category_id = ClientCategoryMapping.find_by(client_category_id:client_category_id).category_id rescue nil
    #   rule = DispositionRule.find_by(category_id:@temp_category_id).rule rescue nil
    # end
    # rule_definition = rule.rule_definition
    # rule_condition = rule.condition
    # rule_precedence = rule.precedence 

    # disposition_arr = []
    # rule_cond_obj = {}
    # rule_def_obj= {}
    # rc_name = ""
    # cond = {}
    # temp_statuses = []


    # rule_definition.each do |rd|
    #   a = rd["definition"].split(' ')
    #   temp_statuses = temp_statuses | a.values_at(* a.each_index.select {|i| i.even?})
    # end

    # temp_statuses.each do |ts|
    #   eval("#{ts} = false")
    # end

    # rule_condition.each do |rc|

    #   rule_cond_obj = rc
    #   rc_name = rule_cond_obj["name"]
    #   cond = rule_cond_obj["condition"]

    #   temp_statuses.each do |ts|

    #   next if ts == "@mrp_level"
    #     eval("#{ts} = #{cond[ts[1..-1]].include?(processed_grading_result[ts[1..-1]])}")
    #   end

    #   rule_definition.each do |rd|
    #     if rd["name"] == rc_name
    #       if eval(rd["definition"])
    #         disposition_arr << rc_name
    #       end
    #     end
    #   end

    #   max = -1
    #   maxKey = "" 

    #   disposition_arr.each do |da|
    #     if rule_precedence[da].to_i > max
    #       max = rule_precedence[da].to_i
    #       maxKey = da
    #     end
    #   end

    #   final_disposition = maxKey
    # end
      
    # if final_disposition == "Repair"
    #   final_disposition = "Liquidation"
    # end
    # if processed_grading_result["Item Condition"] == "Missing"
    #   final_grade = "Not Tested"
    # end

    inventory.grade = final_grade
    rule_name = ""

    

    
    #inventory.disposition = final_disposition
    if inventory.save
      #Create Grading Details record

      final_disposition ,final_flow = ClientDispositionRule.calculate_disposition(client_category_id,inventory.id, '')
      inventory.details["disposition"] = final_disposition[:disposition]
      inventory.details["work_flow_name"] = final_disposition[:flow]
      
      inventory.disposition = final_disposition[:disposition]
      inventory.save
      grade_id = LookupValue.where(original_code: final_grade).last.id rescue nil
      grading_detail = inventory.inventory_grading_details.new(distribution_center_id: inventory.distribution_center_id, user_id: user.id)
      grading_detail.details = {}
      grading_detail.details["processed_grading_result"] = processed_grading_result
      grading_detail.details['final_grading_result'] = final_grading_result
      grading_detail.details["warehouse_inwarding_date"] = Time.now.to_s
      grading_detail.is_active = true
      grading_detail.grade_id = grade_id
      grading_detail.save
    end

    gate_pass_inventory.inwarded_quantity = gate_pass_inventory.inwarded_quantity + 1
    gate_pass_inventory.save

    if !current_user.distribution_centers.pluck(:id).include?(gate_pass_inventory.gate_pass.destination_id)
      gatepass = gate_pass_inventory.gate_pass
      received = current_user.distribution_centers.last
      gatepass.update_attributes(received_id: received.id, 
                                received_address: received.address, 
                                received_city: received.city.original_code, 
                                received_state: received.state.original_code, 
                                received_country: received.country.original_code,
                                received_time: Time.now.to_s
                                )

      inv_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_issue_resolution).first
      inventory.inventory_statuses.create(status_id: inv_status.id, user_id: current_user.id,
      distribution_center_id: inventory.distribution_center_id)
      inventory.details["issue_type"] = "Incorrect Location"
      inventory.details["source_code"] = gatepass.source_code
      inventory.details["destination_code"] = gatepass.destination_code
      inventory.save
    end

    if gate_pass_inventory.inwarded_quantity == gate_pass_inventory.quantity
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_fully_received).first
      gate_pass_inventory.update_attributes(status_id: gp_status.id, status: gp_status.original_code)
      
    elsif gate_pass_inventory.inwarded_quantity > gate_pass_inventory.quantity
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
      gate_pass_inventory.update_attributes(status_id: gp_status.id, status: gp_status.original_code)
    
    else
      gp_status =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_part_received).first
      gate_pass_inventory.update_attributes(status_id: gp_status.id, status: gp_status.original_code)

    end

    render json: {grade:final_grade, disposition: final_disposition , processed_grading_result: processed_grading_result, inventory_id: inventory.id, status:200}
  end


  def calculate_grade_new
    final_grading_result = params["final_grading_result"]
    user = @current_user

    if params['gatepass_inventory_id'].blank? || params['gatepass_inventory_id'] == 0
      gatepass = GatePass.includes(:gate_pass_inventories).where(client_gatepass_number: params["client_gate_pass_number"]).last
      gate_pass_inventory = gatepass.gate_pass_inventories.where(sku_code: params["sku_code"]).last
      client_sku = ClientSkuMaster.where(code: params["sku_code"]).last
    else
      gate_pass_inventory = GatePassInventory.includes(:gate_pass).where(id: params['gatepass_inventory_id']).last
      gatepass = gate_pass_inventory.gate_pass
      client_sku = ClientSkuMaster.where(code: gate_pass_inventory.sku_code).last
    end
    client_category_id = client_sku.client_category_id 
    
    if gatepass.present?
      inventory = Inventory.new()
      category_l1 = ""
      category_l2 = ""
      ClientCategory.find(client_category_id).ancestors.each_with_index do |cat, index|
        if index == 0
          category_l1 = cat.name 
        end
        if index == 1
          category_l2 = cat.name 
        end
      end
      return_reason = params['return_reason'] 
      inventory.return_reason = return_reason
      inventory.details = {"stn_number" => gatepass.client_gatepass_number,
        "dispatch_date" => gatepass.dispatch_date.strftime("%Y-%m-%d %R"),
        "return_reason" => return_reason,
        "client_category_id" => client_category_id,
        "brand" => client_sku.brand,
        "sku_code" => client_sku.code
      }

      processed_grading_result = {}
      grading_error = ""
      
      grading_type = params[:grading_type].present? ? params[:grading_type] : "Warehouse"
      category = ClientCategory.find(client_category_id) rescue nil
      # final_grade, processed_grading_result , grading_error = ClientCategoryGradingRule.calculate_grade(client_category_id,final_grading_result,grading_type)
      label = client_sku.try(:own_label) ? "Own Label" : "Non Own Label"
      # final_disposition  = ClientDispositionRule.calculate_disposition(return_reason, label, final_grade)
      # API for rule engine starts
      url =  Rails.application.credentials.rule_engine_url+"/api/v1/grades/compute_grade"
      serializable_resource = {category: category.name, grade_type: grading_type, final_grading_result: final_grading_result}.as_json
      response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      # API for rule engine ends
      parsed_response = JSON.parse(response)
      final_grade = parsed_response["grade"]
      grading_error = parsed_response["grading_error"]
      processed_grading_result = parsed_response["processed_grading_result"]

      # API for rule engine starts
      url =  Rails.application.credentials.rule_engine_url+"/api/v1/dispositions"
      serializable_resource = {category: category.name, brand: label}.as_json
      answers = [{"test_type"=>"Grade", "output" => final_grade},{"test_type"=>"Own Label", "output" => label},{"test_type"=>"Return Reason", "output" => return_reason}]
      serializable_resource = {client_name: "croma", answers: answers}.as_json
      response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      if response.body == "Insurance" && gate_pass_inventory.map.to_i <= 1500
        final_disposition = {disposition: "Liquidation", flow: "NA"}
      else
        final_disposition = {disposition: response.body, flow: "NA"}
      end
      # API for rule engine ends

      disposition_names =  LookupKey.where(name: "WAREHOUSE_DISPOSITION").last.lookup_values.pluck(:original_code)
      policy_types = LookupKey.where(name: "POLICY").last.lookup_values.collect {|t| {t.original_code => t.code}}
      render json: {grade: final_grade,grade_error: grading_error , disposition: final_disposition , processed_grading_result: processed_grading_result, final_grading_result: final_grading_result, disposition_names: disposition_names, policy_types: policy_types}
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  def create_inventories
    param = JSON.parse(params["inventory_data"])
    document_params = params[:documents]
    # Create Inventory Data
    begin
      ActiveRecord::Base.transaction do
        gate_pass = GatePass.includes(:gate_pass_inventories).where("lower(client_gatepass_number) = ?", "#{param["client_gate_pass_number"].downcase}").last
        if param['gatepass_inventory_id'] == 0

          # This condition will happen when :-
          # suppose if user has 2 LG TVs but he wanted to grade 2 Refrigerators which is not present yet.
          # so we will not get "gate_pass_inventory_id" in parameters. 


          gate_pass_inventory = gate_pass.gate_pass_inventories.where("sku_code = ?",  param["sku_code"]).last
          if (gate_pass_inventory.present?) && (gate_pass_inventory.quantity > 0)
            
            # This condition will happen when :-
            #  suppose if user has 2 LG TVs but he wanted to grade 2 Refrigerators. 
            #  So In this case IF gate_pass_inventory is already present for 2 refrigerators with quantity more than 0. (means for new SKU)
            #  So we will not create new gate pass inventory and will throw below message.

            render json: {message: "Incorrect Data Passed", status: 302}
            return
          else

            # This else condition will happen when :-
            #  suppose if your have 2 LG TVs but He wanted to grade 2 Rerigerator 
            #  So In this case gate_pass_inventory will be blank for 2 refrigerators (means for new SKU)
            #  So we will create new gate pass inventory. and further Inventory also.

            # In this case Status of this gatepass inventory will be "Excess". Because These items received in excess quantity.

            client_sku = ClientSkuMaster.where("lower(code) = ?", param["sku_code"].downcase).last
            gatepass_inventory_status_excess_received =  LookupValue.where("code = ?", Rails.application.credentials.gatepass_inventory_status_excess_received).first
            gate_pass_inventory = gate_pass.gate_pass_inventories.new(distribution_center_id: gate_pass.distribution_center_id, client_id: gate_pass.client_id, user_id: current_user.id, sku_code: param["sku_code"], item_description: client_sku.sku_description, quantity: 0, status: gatepass_inventory_status_excess_received.original_code, status_id: gatepass_inventory_status_excess_received.id, map: client_sku.mrp, client_category_id: client_sku.client_category_id,
            ean: client_sku.ean, client_category_name: client_sku.client_category.try(:name), brand: client_sku.brand, inwarded_quantity: 0, client_sku_master_id: client_sku.try(:id))

            gate_pass_inventory.details = {"own_label"=> client_sku.own_label}

            inventories = Inventory.where(tag_number: param["tag_number"])
            if inventories.blank?
              if gate_pass_inventory.save && gate_pass_inventory.create_inventory_data(param, current_user, document_params)
                render json: {result: gate_pass_inventory, status: 200}
              else
                render json: {message: "Error in inwarding inventory", status: 302}
              end
            else
              render json: {message: "This tag number is already present in the system", status: 302}
            end
          end
        else

          # This condition will happen when :-
          # suppose if user has 2 LG TVs and he wanted to grade 1 LG TV. Here we are getting gate_pass_inventory_id in params.
          # so we will find that "gate_pass_inventory" for LG and create new Inventory out of that. 


          # gate_pass_inventory = GatePassInventory.where(id: param['gatepass_inventory_id']).last
          gate_pass_inventories = gate_pass.gate_pass_inventories.where("sku_code = ?",  param["sku_code"])
          gate_pass_inventory = nil
          gate_pass_inventories.each do |gate_pass_inv|
            if gate_pass_inv.inwarded_quantity < gate_pass_inv.quantity
              gate_pass_inventory = gate_pass_inv
              break
            end
          end
          gate_pass_inventory = GatePassInventory.where(id: param['gatepass_inventory_id']).last if gate_pass_inventory.nil?
          grade = LookupValue.where("code = ?", Rails.application.credentials.inventory_grade_not_tested).first
          in_transit_inventory = Inventory.where(gate_pass_inventory_id: gate_pass_inventory.id, grade: grade.original_code, disposition: nil, serial_number: nil).first
          
          # Now Here comes one condition.

          # Suppose user has one gatepass_inventory with quantity 8 and inwarded quantity 0.
          # Now He inwarded 5 items out of 8 of that gatepass_inventory and click on proceed to GRN
          # There at proceed_grn, You will see that we are creating New Inventories with disposition nil, grade "Not Tested" and serial number "N/A".
          # Number of new inventory created will be (inwarded quantity - quantity)
          # So Here We will find that we already have that inventory or not. If we have then
          # we will update that, if not then we will create it. 

          if in_transit_inventory.present?
            if gate_pass_inventory.update_inventory_data(param, current_user, document_params, in_transit_inventory)
              render json: {result: gate_pass_inventory, status: 200}
            else
              render json: {message: "Error in inwarding inventory", status: 302}
            end
          else
            inventories = Inventory.where(tag_number: param["tag_number"])
            if inventories.blank?
              result = gate_pass_inventory.create_inventory_data(param, current_user, document_params)
              if result == true
                render json: {result: gate_pass_inventory, status: 200}
              else
                if (result[1].present? && result[1][:error].present?)
                  render json: {message: "#{result[1][:error]}", status: 302}
                else
                  render json: {message: "Error in inwarding inventory", status: 302}
                end
              end
            else
              render json: {message: "This tag number #{inventories.last.tag_number} with Article #{inventories.last.sku_code} is already present in the system with STN #{inventories.last.gate_pass.client_gatepass_number}", status: 302}
            end
          end
        end
      end
    rescue Exception => message
      Rails.logger.warn "Issue in Tag Number #{param['tag_number']} ----- #{message}"      
      render json: {message: "Server Error", status: 302}
    end
  end

  def update_inventory
    @inventory = Inventory.find(params['inventory_id'])
    if @inventory.present?
      @inventory.update_attributes(toat_number: params["toat_number"], tag_number: params['tag_number'])
      render json: {inventory_id: @inventory.id}
    else
      render json: {message: "Not Found", status: 302}
    end
  end

  private
    def set_gate_pass
      @gate_pass = GatePass.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def gate_pass_params
      params.fetch(:gate_pass, {})
    end

    def get_report_status(type)
      return false if Rails.env == 'development'
      report_for = current_user.roles.include?('site_admin') ? 'site_admin' : "central_admin"
      if report_for == 'site_admin'
        report = current_user.report_statuses.where(distribution_center_ids: current_user.distribution_centers.pluck(:id), status: 'In Process', report_type: type, created_at: (Time.zone.now - 30.minutes)..(Time.zone.now), report_for: report_for)
      else
        report = current_user.report_statuses.where(status: 'In Process', report_type: type, created_at: (Time.zone.now - 30.minutes)..(Time.zone.now), report_for: report_for)
      end
      if report.present?
        return true
      else
        current_user.report_statuses.create(status: 'In Process', report_type: type, distribution_center_ids: current_user.distribution_centers.pluck(:id), report_for: report_for) if report_for == 'site_admin'
        current_user.report_statuses.create(status: 'In Process', report_type: type, report_for: report_for) if report_for == 'centrel_admin'
        return false
      end
    end
end
