class Api::V1::GradingsController < ApplicationController

  def fetch_regrade_inventories
    @pending_liquidation_regrade = Liquidation.where(status:LookupValue.find_by(code:Rails.application.credentials.liquidation_regrade_pending_status).original_code,distribution_center_id:current_user.distribution_centers, is_active: true)
    #@pending_repair_regrade = Repair.where(status:LookupValue.find_by(code:Rails.application.credentials.repair_status_pending_repair_grade).original_code ,distribution_center_id:current_user.distribution_centers, is_active: true)
    @pending_repair_regrade = Repair.where(status: LookupValue.find_by(code:Rails.application.credentials.repair_status_pending_repair).original_code ,distribution_center_id:current_user.distribution_centers, is_active: true, request_to_grade: true)
    
    render json: {liquidation: JSON.parse(@pending_liquidation_regrade.to_json(:methods => :request_number)), repair: @pending_repair_regrade}
  end

  def category_rules
    grading_type = params[:grading_type].present? ? params[:grading_type] : "Own Label"
    # @category = ClientCategoryGradingRule.find_by(client_category_id:params[:id], grading_type: grading_type) rescue nil
     
    # if @category.present?
    #   @test_rule = TestRule.find(@category.test_rule_id) rescue nil
    #   @grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
    # else
    #   @category_id = ClientCategoryMapping.find_by(client_category_id:params[:id]).category_id rescue nil
    #   @category = CategoryGradingRule.find_by(category_id:@category_id, grading_type:grading_type) rescue nil
    #   @test_rule = TestRule.find(@category.test_rule_id) rescue nil
    #   @grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
    # end
    # @client_category_mapping = ClientCategoryMapping.find_by(client_category_id:params[:id]) rescue nil

    # if @test_rule.present? && @grade_rule.present?
    #   render json: {test_rule: @test_rule.rules , grading_rule_id: @grade_rule.id , test_rule_id: @test_rule.id}
    # elsif !@test_rule.present? && !@grade_rule.present?
    #   render json: {message: "Test questions and grading rules not found", status: 302}
    # elsif !@test_rule.present?
    #   render json: {message: "Test questions not found", status: 302}
    # elsif !@grade_rule.present?
    #   render json: {message: "Grading rules not found", status: 302}
    # end
    category = ClientCategory.find(params[:id]) rescue nil
    # API for rule engine starts
    url =  Rails.application.credentials.rule_engine_url+"/api/v1/grades/questions"
    serializable_resource = {category: category.name, grade_type: grading_type}.as_json
    response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    render json: response
    # API for rule engine ends
  end

  def calculate_grade
    grade_error =""
    
    final_grading_result = params["final_grading_result"]
    user = @current_user

    client_sku = ClientSkuMaster.where(code: params["sku_code"]).last rescue nil

    

    client_category_id = params["client_category_id"].present? ? params["client_category_id"] : client_sku.client_category_id

    
    inventory = Inventory.new()
    
    graded_inventory = Inventory.find(params[:inventory_id])
    

    processed_grading_result = {}
    grading_type = params[:grading_type].present? ? params[:grading_type] : "Own Label"

    final_grade, processed_grading_result ,grade_error= ClientCategoryGradingRule.calculate_grade(client_category_id,final_grading_result,grading_type)
   
   

      final_disposition = nil
      final_flow = nil

    disposition_names =  LookupKey.where(name: "WAREHOUSE_DISPOSITION").last.lookup_values.pluck(:original_code)
    policy_types = LookupKey.where(name: "POLICY").last.lookup_values.collect {|t| {t.original_code => t.code}}
    render json: {grade: final_grade, grade_error: grade_error, disposition: final_disposition , processed_grading_result: processed_grading_result, final_grading_result: final_grading_result, disposition_names: disposition_names, policy_types: policy_types }
  end

  def send_images_to_ai
    inventory = Inventory.find(params[:inventory_id])
    raise "Inventory cannot be blank" and return if inventory.blank?
    inventory_grading_detail = inventory.inventory_grading_details.order('id desc').first
    raise "No Grading details are present" and return if inventory_grading_detail.blank?

    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

    bucket = Rails.application.credentials.aws_bucket
    ai_discrepancy_hash = {}
    ai_payload = []    
    data_with_annotations = []
    
    begin
      ActiveRecord::Base.transaction do
        params["final_grading_result"]["Physical Condition"].select { |d| data_with_annotations += d['imageHolders'] if d['imageHolders'].present? }
    
        data_with_annotations.each do |data_with_annotation|
          orignal_path_name = data_with_annotation["imageSrc"].gsub(amazon_s3.bucket(bucket).url, "")
          file_name = "item_#{inventory.tag_number}_#{rand(1000..2000)}"
    
          ai_payload << {
            "File_ID": "#{inventory.tag_number}_#{data_with_annotation["side"].downcase}",
            "File_Path": orignal_path_name,
            "File_Name": file_name,
            "tag_number": inventory.tag_number,
            "Side": data_with_annotation["side"],
            "Predictions": [],
            "File_Remarks": ""
          }
    
          ai_discrepancy_hash["#{data_with_annotation["side"]}"] = {
            "match_status" => false,
            "orignal_image_url" => data_with_annotation["imageSrc"],
            "human_identified" => {
              "image_url" => data_with_annotation["annotatedImageSrc"],
              "defects" => data_with_annotation["coordinatesList"].collect{|d| d["defectType"]}
            }
          }    
        end
        inventory_grading_detail.details['final_grading_result']['ai_discrepancy'] = ai_discrepancy_hash
        inventory_grading_detail.save!

        headers = {"Content-Type" => "application/json"}
        RestClient::Request.execute(:method => :post, :url => "https://qa-docker.blubirch.com:3201", :payload => ai_payload.to_json, headers: headers)
        render json: {message: "Success", ai_response: ai_payload }
      end
    rescue => exception
      raise exception.message
    end
  end

  def update_ai_details
    raise "Ai response data cannot be blank be blank" and return if params['ai_response'].blank?
    inventory = nil
    inventory_grading_detail = nil
    total_defect_score = []
    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)

    bucket = Rails.application.credentials.ai_bucket
    begin
      ActiveRecord::Base.transaction do
        params['ai_response'].each do |ai_response|
          file_id = ai_response["File_ID"]
          inventory_tag_number, side = file_id.split('_')
          inventory = Inventory.find_by(tag_number: inventory_tag_number) if inventory.blank?
          raise 'Inventory not found' if inventory.blank?
          inventory_grading_detail = inventory.inventory_grading_details.order('id desc').first if inventory_grading_detail.blank?
          raise "No Grading details are present" and return if inventory_grading_detail.blank?
    
          side_data = inventory_grading_detail.details["final_grading_result"]["ai_discrepancy"][side.capitalize]
          raise "#{side.capitalize} Not found" if side_data.blank?
          side_data['ai_identified'] = {}
    
          side_data['ai_identified'] = {
            "image_url" => "#{amazon_s3.bucket(bucket).url}/#{ai_response["File_Path"]}"
          }      
          
          total_defect_score << side_data['human_identified']['defects_score']
          side_data['ai_identified']['defects'] = []
    
          ai_response["Predictions"].each do |prediction|
            side_data['ai_identified']['defects'] << prediction["Label"] if prediction["Label"].present?
            side_data['ai_identified']['defects_score'] = prediction["Confidence_Score"] if prediction["Confidence_Score"].to_f > 0
            total_defect_score << prediction["Confidence_Score"] if prediction["Confidence_Score"].to_f > 0
          end
          side_data["match_status"] = (side_data['human_identified']['defects'].sort == side_data['ai_identified']['defects'].sort)
        end
    
        total_score = total_defect_score.map(&:to_f).inject(:*)
        inventory_grading_detail.save!
        inventory_grading_detail.details['processed_grading_result']['ai_discrepancy'] =  InventoryGradingDetail.calculate_weightage_grade(total_score)
        inventory_grading_detail.save!
        render json: {message: "Success"}
      end
    rescue => execp
      raise and return execp.message
    end
    
  end

  def store_grade
    inventory = Inventory.includes(:inventory_statuses, :liquidation, :repair).find(params[:inventory_id])
    details = inventory.details
    details["grade"] = params[:grade]

    if params[:disposition] == "Liquidation"
      if params["policy_type"].present?
        policy_type = LookupValue.find_by(code: params["policy_type"])
        details["policy_id"] = policy_type.id rescue nil
        details["policy_type"] = policy_type.original_code rescue nil
      end
    end

    bucket_record = nil 
    bucket_details = nil
    new_status = nil
    history = nil
    begin
      ActiveRecord::Base.transaction do
        if inventory.liquidation.present?
          bucket_record = inventory.liquidation
          new_status = LookupValue.find_by(code:Rails.application.credentials.liquidation_status_pending_rfq_status)
          # history = LiquidationHistory.create(liquidation_id:bucket_record.id,status:new_status.original_code,status_id: new_status.id)
          inventory.update(details: details,disposition: "Liquidation", toat_number: params[:toat_number], grade: params[:grade])
        elsif inventory.repair.present?
          bucket_record = inventory.repair
          #new_status = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition)
          new_status = LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair)
          # history = RepairHistory.new(repair_id:bucket_record.id,status:new_status.original_code,status_id:new_status.id)
          # history.details = {}
          # # history.details = {"pending_repair_initiation_created_date" => Time.now.to_s }
          # history.details = {"pending_repair_initiation_closed_date" => Time.now.to_s }
          # history.save
          bucket_record.update!(request_to_grade: false)
          inventory.update(details:details,disposition: params[:disposition], toat_number: params[:toat_number], grade: params[:grade])
          
          if params[:disposition] != "Repair"
            bucket_record.update(is_active: false)
            if inventory.disposition == "E-Waste"
              bucket_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_e_waste).first
            elsif inventory.disposition == "Pending Transfer Out"
              bucket_status =  LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_pending_markdown).first
            else
              code = 'inventory_status_warehouse_pending_'+ inventory.disposition.try(:downcase).try(:parameterize).try(:underscore)
              bucket_status =  LookupValue.find_by_code(Rails.application.credentials.send(code))
            end
            inventory.inventory_statuses.where(is_active: true).update_all(is_active: false) if inventory.inventory_statuses.present?
            inventory.inventory_statuses.create(status_id: bucket_status.id, user_id: current_user.id, distribution_center_id: inventory.distribution_center_id, 
                                                details: {"user_id" => current_user.id, "user_name" => current_user.username})
            DispositionRule.create_bucket_record(inventory.disposition, inventory, "Regrade", current_user.id)
          end
        
        end
        bucket_details = bucket_record.details
        if params[:disposition] == "Liquidation"
          bucket_details["policy_type"] = policy_type.original_code rescue nil
          bucket_details["policy_id"] = policy_type.id rescue nil
        end
        bucket_record.update(status_id: new_status.id,status:new_status.original_code, grade: params[:grade] , details: bucket_details)
        if bucket_record.class.name == "Liquidation"
          liq_repuest = bucket_record.liquidation_request
          if liq_repuest.graded_items < liq_repuest.total_items
            liq_repuest.graded_items = liq_repuest.graded_items+1
            liq_repuest.save
          end
        end
        InventoryGradingDetail.store_grade_inventory(params[:inventory_id],params[:final_grading_result],params[:processed_grading_result],params[:grade],current_user)
        render json: {message: "Sucess"}
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

end
