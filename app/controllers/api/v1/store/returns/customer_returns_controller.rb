require 'aws-sdk-v1'
require 'aws-sdk'

class Api::V1::Store::Returns::CustomerReturnsController < ApplicationController

  def check_sku
    @sku_master = ClientSkuMaster.where(code: params[:sku_code]).last
    render json: @sku_master
  end


  def category_rules
  	
  	# @category = TestRule.last
    @inventory_details = Inventory.find(params[:inventory_id]).details rescue nil
    if @inventory_details.present?
      @inventory_details["category_name"] = ClientCategory.find(params[:id]).name 
    end
  	@category = ClientCategoryGradingRule.find_by(client_category_id:params[:id],grading_type: params[:grading_type]) rescue nil
  	 
    if @category.present?
     
  		@test_rule = TestRule.find(@category.test_rule_id) rescue nil
  		@grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
  	else
  		@category_id = ClientCategoryMapping.find_by(client_category_id:params[:id]).category_id rescue nil
  		@category = CategoryGradingRule.find_by(category_id:@category_id,grading_type: params[:grading_type]) rescue nil
  		@test_rule = TestRule.find(@category.test_rule_id) rescue nil
  		@grade_rule = GradingRule.find(@category.grading_rule_id) rescue nil
  	end
  	@client_category_mapping = ClientCategoryMapping.find_by(client_category_id:params[:id]) rescue nil

  	render json: {inventory_details:@inventory_details,test_rule: @test_rule.rules , grading_rule_id: @grade_rule.id , test_rule_id: @test_rule.id}


  end

  def warehouse_rules
    @inventory = Inventory.find_by(tag_number:params[:tag_number])
    render json: {inventory: @inventory}
  end



  def generate_rr 
    # params = params.permit!
  	final_grading_result = params[:final_grading_result]
  	processed_grading_result = {}
    client_category_id = params[:selected_inventory][:client_category_id]
    grading_type = params[:grading_type].present? ? params[:grading_type] : nil
    @category = ClientCategoryGradingRule.find_by(client_category_id: client_category_id,grading_type: grading_type)
    if !@category.present?
      @category_id = ClientCategoryMapping.find_by(client_category_id:params[:id]).category_id rescue nil
      @category = CategoryGradingRule.find_by(category_id:@category_id,grading_type: grading_type) rescue nil
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
          if  res["output"] != "" && test_precedence["#{key}_precedence"][res["output"]] > max
            max = test_precedence["#{key}_precedence"][res["output"]]
            maxKey = res["output"]
          end
        end

        processed_grading_result[key] = maxKey

  		# if key == "Functional"
  		# 	temp = final_grading_result[key]
  		# 	final_grading_result[key].each do |res|
  		# 		if  res["output"] != "" && test_precedence["functional_precedence"][res["output"]] > max
  		# 			max = test_precedence["functional_precedence"][res["output"]]
  		# 			maxKey = res["output"]
  		# 		end
  		# 	end

  		# 	processed_grading_result[key] = maxKey

  		# elsif key == "Physical"

    #     temp = final_grading_result[key]
    #     final_grading_result[key].each do |res|
    #       if  res["output"] != "" && test_precedence["Physical_precedence"][res["output"]] > max
    #         max = test_precedence["Physical_precedence"][res["output"]]
    #         maxKey = res["output"]
    #       end
    #     end
  		# 	processed_grading_result[key] = maxKey
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
    	
    #grading ends



  	#disposition starts

  	#rule = Rule.first
    rule = ClientDispositionRule.find_by(client_category_id:client_category_id).rule rescue nil
    if !rule.present?
      @temp_category_id = ClientCategoryMapping.find_by(client_category_id:client_category_id).category_id rescue nil
      rule = DispositionRule.find_by(category_id:@temp_category_id).rule rescue nil
    end
  	rule_definition = rule.rule_definition
  	rule_condition = rule.condition
  	rule_precedence = rule.precedence 

  	disposition_arr = []
  	rule_cond_obj = {}
  	rule_def_obj= {}
  	rc_name = ""
  	cond = {}
  	temp_statuses = []


  	rule_definition.each do |rd|
  		a = rd["definition"].split(' ')
  		temp_statuses = temp_statuses | a.values_at(* a.each_index.select {|i| i.even?})
  	end

  	temp_statuses.each do |ts|
  		eval("#{ts} = false")
  	end

  	rule_condition.each do |rc|

  		rule_cond_obj = rc
  		rc_name = rule_cond_obj["name"]
  		cond = rule_cond_obj["condition"]



  		temp_statuses.each do |ts|

  		next if ts == "@mrp_level"
  			eval("#{ts} = #{cond[ts[1..-1]].include?(processed_grading_result[ts[1..-1]])}")
  		end

  		rule_definition.each do |rd|
  			if rd["name"] == rc_name
  				if eval(rd["definition"])
  					disposition_arr << rc_name
  				end
  			end
  		end

      max = -1
      maxKey = "" 

  		disposition_arr.each do |da|
  			if rule_precedence[da].to_i > max
  				max = rule_precedence[da].to_i
          maxKey = da
  			end
  		end

  		final_disposition = maxKey

  	end
    
    @tag_number =  "T-#{SecureRandom.hex(3)}".downcase
    final_disposition = "Send to factory"
    
    status , @rr_number, inventory_id,result, final_grade = ReturnRequest.create_inventory_after_grading(Invoice.find(params[:invoice_id]), params[:selected_inventory], params[:customer_return_reason_id], current_user , true , @tag_number , params[:final_grading_result] , processed_grading_result , final_grade, final_disposition)
    
    render json: {rr_number:@rr_number,created_inventory_id: inventory_id ,tag_number: @tag_number , grade:final_grade , disposition:final_disposition  , processed_grading_result: processed_grading_result}

  end

  def finalize_grading
    inventory = Inventory.find(params[:inventory_id])
    inventory.details["serial_number"] = params[:serial_number]
    if inventory.save
      render json: {status: "Success"}
    else
      render json: {status: "Failed"}
    end
    
  end


  def upload
  	img_data = params[:image_url]


	  file_name = params["image_name"].present? ? params["image_name"] : "item_#{rand(1000000).to_s}.png"
	  data_uri_parts = img_data.match(/\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m) || []
	  extension = "png"

     #default
    if params[:is_screenshot]
      path_name = "public/uploads/screenshot_annotation_images/#{file_name}"    
    else
      path_name = "public/uploads/annotation_images/#{file_name}"
    end
	  

    service = AWS::S3.new(:access_key_id => Rails.application.credentials.access_key_id,
                             :secret_access_key => Rails.application.credentials.secret_access_key  , region: Rails.application.credentials.aws_s3_region)
    bucket_name = Rails.application.credentials.aws_bucket

    bucket = service.buckets[bucket_name]

    bucket.acl = :public_read
    
    key = path_name
    s3_file = service.buckets[bucket_name].objects.create(key,Base64.decode64(data_uri_parts[2]),{content_type:'image/png', content_encoding: 'base64',acl:"public_read"})
    path_name=path_name[6..path_name.length]
	  
	  render json: {path_name: s3_file.public_url.to_s}
  end

  def delete_images

    service = AWS::S3.new(:access_key_id => Rails.application.credentials.access_key_id,
                             :secret_access_key => Rails.application.credentials.secret_access_key  , region: Rails.application.credentials.aws_s3_region)
    bucket_name = Rails.application.credentials.aws_bucket


    Aws.config.update(
    credentials: Aws::Credentials.new(Rails.application.credentials.access_key_id, Rails.application.credentials.secret_access_key),
    region: Rails.application.credentials.aws_s3_region)

    params[:url].each do |u|

      b = u.split('/')
      path = b[3..b.length].join('/')
     
      s3 = Aws::S3::Resource.new.bucket(Rails.application.credentials.aws_bucket)
      obj = s3.object(path)
      obj.delete
    end
    render json: "success"
  end

end