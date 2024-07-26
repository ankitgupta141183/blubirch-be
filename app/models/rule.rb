class Rule < ApplicationRecord
	acts_as_paranoid
	has_many :disposition_rules
	has_many :client_disposition_rules

	 #serialize :rule_definition, Array
	 #serialize :condition, Array

	# def self.import(file)
	# 	CSV.foreach(file.path, headers: true) do |row|
	# 		Rule.create! row.to_hash
	# 	end
	# end



	  def self.import_disposition_rules(file = nil,disposition_type = nil)  	
	    begin
	    	
				ActiveRecord::Base.transaction do

					if (!file.present?)
						file = File.new("#{Rails.root}/public/master_files/disposition_rules.csv")
					end
					data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
					headers = data.headers

					categories_size = headers.count { |x| x.include?("Category L") }
					category_ids = []
	   		 	rule_hash = Hash.new
	   		 	test_rule_hash = Hash.new
	   		 	precedence = {}
	   		 	condition = []
	   		 	definition = []
	        
	        data.each_with_index do |row, index|

						# Code for fetching of catgory ids for uniq test andd grading rule starts

	        	categories_array = []
	        	(1..categories_size).each do |category_number|
	        		categories_array << row["Category L#{category_number}"]
	        	end
	        	
	        	if categories_array.present?
	        		last_category = nil
					categories_array.compact.each_with_index do |individual_category, index|
			            if index == 0
			              last_category = Category.where(code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
			            else
			              last_category = last_category.descendants.where(code: "#{last_category.name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}").last if last_category.present?
			            end
	          		end
	   		 		category_ids << last_category.try(:id)	        	
	   		 	end

	   		 		output =row["Output"]  
	   		 		if output.present?

	   		 			precedence[output] = row["Precedence"]
	   		 			 definition << {"name" => output , "definition" => row["Rule Definition"]} 
	   		 			 
	   		 			 condition_hash = {}
	   		 			 condition_hash["Physical"] = row["Physical Status"].split(',') rescue []
	   		 			 condition_hash["Functional"] = row["Functional Status"].split(',') rescue []
	   		 			 condition_hash["Packaging"] = row["Packaging Status"].split(',') rescue []

	   		 			 condition << {"name" => output , "condition" => condition_hash} 

	   		 		end
	   		 		
	        end # data loop ends   

	        rule_hash["precedence"] = precedence
	        rule_hash["rule_definitions"] = definition
	        rule_hash["rule_conditions"] = condition

	        rule=Rule.create(precedence: precedence , condition: condition , rule_definition: definition)
	        category_ids.each do |c|
	        	DispositionRule.create(category_id: c, rule_id: rule.id , disposition_type: disposition_type )
	        end

	        # DispositionRule.create(category_id:678, rule_id: rule.id)# fr demo purposes
	        # ClientCategoryGradingRule.create(client_category_id: 678, test_rule_id: 3, grading_rule_id: 3)
				end # transaction ends
				# master_file_upload.update(status: "Completed")
			rescue
				#master_file_upload.update(status: "Error")
			end
	  end


    def self.import_client_disposition_rules(file = nil,disposition_type = nil)  	
      begin        	
  			ActiveRecord::Base.transaction do

  				if (!file.present?)
  					file = File.new("#{Rails.root}/public/master_files/DispositionRules/Disposition_Rules.csv")
  				end
  				file = File.new(file) if file.present?
  				data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
  				headers = data.headers

  				categories_size = headers.count { |x| x.include?("Category L") }
  				category_ids = []
     		 	rule_hash = Hash.new
     		 	test_rule_hash = Hash.new
     		 	precedence = {}
     		 	condition = []
     		 	
          
          data.each_with_index do |row, index|
          	definition = {}
          	ClientDispositionRule.create(return_reason: row["Return-Reason"] ,label:row["Own Label"],flow_name: row["Flow Name"],client_category_id: nil, brand_id: nil, model_id: nil, rule_id: nil,  name: nil, client_category_name: nil, brand_name: row["Brand"], item_model_name: row["Model"], sku_code: row["SKU"] , disposition: row["Disposition"], grade_precedence: row['Grade Precedence'], grade: row['Grade'])


  					# Code for fetching of catgory ids for uniq test andd grading rule starts
			# concatted_category_name = ""
   #        	categories_array = []
   #        	(1..categories_size).each do |category_number|
   #        		categories_array << row["Category L#{category_number}"]
   #        	end
          	
   #        	if categories_array.present?
   #        		last_category = nil
	  #   		categories_array.compact.each_with_index do |individual_category, index|
		 #            if index == 0
		 #              last_category = ClientCategory.where(code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
		 #            else
		 #              last_category = last_category.descendants.where(name: individual_category).last
		 #            end
		 #            concatted_category_name = concatted_category_name + last_category.name + " "
   #        		end
	  #      		 	category_ids << last_category.try(:id)	        	
	  #      	end

   # 		 	if row["Brand"].present?
   # 		 		concatted_category_name = concatted_category_name + row["Brand"] + " "
   # 		 	end

   # 		 	if row["SKU"].present?
   # 		 		concatted_category_name =  concatted_category_name + row["SKU"]
   # 		 	end

   #     		concatted_category_name = concatted_category_name.parameterize.underscore
   # 		 	condition_hash = {}
   # 		 	rd_string = ""
   # 		 	condition_hash
   # 		 	row["Rule Definition"].split(" ").each_with_index do |rd , index|
   # 		 		if index % 2 == 0 
   # 		 			condition_hash[rd.parameterize.underscore] = row[rd]
   # 		 			rd_string = rd_string +"@#{rd.parameterize.underscore}" + " "
   # 		 		else
   # 		 			rd_string = rd_string + rd + " "
   # 		 		end
   # 		 	end

   # 		 	variable_properties_string = ""
   # 		 	row["Variable Properties"].split(" ").each_with_index do |vp,index|
   # 		 		if index % 2 == 0 
   # 		 			condition_hash["Limit-#{vp}"] = row["Limit-#{vp}"]
   # 		 			condition_hash["#{vp}-Operator"] = row["#{vp}-Operator"]
   # 		 			condition_hash["#{vp}-Attr"] = row["#{vp}-Attr"].parameterize.underscore
   # 		 		end
   # 		 	end

   # 		 	condition_hash["resultant_flow"] = row["Flow Name"]

   # 		 	definition["Rule Definition"] = rd_string
   # 		 	definition["Variable Properties"] = row["Variable Properties"]

   		 	#created_rule = Rule.create(rule_definition: definition , condition:condition_hash)       		 
     		 
          end

  			end # transaction ends
  			# master_file_upload.update(status: "Completed")
  		rescue ActiveRecord::StatementInvalid => e
  			#master_file_upload.update(status: "Error")    			
    		puts "=======================#{e.message.inspect}============================"
  		end
  		
    end


      

end
