class CategoryGradingRule < ApplicationRecord
	  
  belongs_to :test_rule, optional: true
  belongs_to :grading_rule, optional: true
  belongs_to :category

  acts_as_paranoid

  def self.import_test_rule(master_file_upload = nil,grading_type = nil)  	
    begin
    	master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
			ActiveRecord::Base.transaction do
				if master_file_upload.present?
          temp_file = open(master_file_upload.master_file.url)
          file = File.new(temp_file)
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        else
          file = File.new("#{Rails.root}/public/master_files/category_grading_tests.csv") if master_file_upload.nil?
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        end
				headers = data.headers

				categories_size = headers.count { |x| x.include?("Category L") }
				category_ids = []
   		 	rule_hash = Hash.new
   		 	test_rule_hash = Hash.new
        precedence_hash = {}
        precedence_name = ""
   		 	functional_precedence = {}
   		 	physical_precedence = {}
        
        data.each_with_index do |row, index|
          precedence = {}
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

   		 		# Code for fetching of catgory ids for uniq test andd grading rule ends

   		 		# Code for fetching of forming rule starts

   		 		if rule_hash.present?
   		 			rule_hash.clone.each do |rule_ref, rule_value|
   		 				if rule_hash.dig(rule_ref).is_a?(Hash)
   		 					if ((rule_value[:test_type].to_s == row["Test Type"].to_s) && (rule_value[:test].to_s == row["Test"].to_s))
   		 						rule_hash[rule_ref][:options] << { "value": row["Options"].to_s,"route": row["Route"].to_s, "output": row["Output"].to_s,
   		 																							 "picture": (row["Picture"] == "Yes" ? true : false), 
   		 																							 "annotation": (row["Annotation"] == "Yes" ? true : false),
   		 																							 "annotation_label": row["Annotation Label"].to_s,
   		 																							 "annotations": (row["Annotations"].present? ? row["Annotations"].split("/").collect(&:strip) : []),
   		 																							 "picture_labels": (row["Picture Labels"].present? ? row["Picture Labels"].split("/").collect(&:strip) : [])}
   		 					else
   		 						self.construct_new_test_rule_hash(rule_hash, row) if (rule_hash.keys.collect{|key| [(rule_hash[key][:test_type] == row["Test Type"]) && (rule_hash[key][:test] == row["Test"]) ]}.flatten.any? == false)
   		 					end
   		 				end
   		 			end
   		 		else
   		 			self.construct_new_test_rule_hash(rule_hash, row)
   		 		end

   		 		# Code for fetching of forming rule ends

   		 		# Code for assigning functional and physical precedence starts

   		 		# if row["Test Type"] == "Functional Precedence"
   		 		# 	if row["Test"].present?
   		 		# 		row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
   		 		# 			functional_precedence.merge!({"#{value}" => index})
   		 		# 		end
   		 		# 	end
   		 		# end

   		 		# if row["Test Type"] == "Physical Precedence"
   		 		# 	if row["Test"].present?
   		 		# 		row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
   		 		# 			physical_precedence.merge!({"#{value}" => index})
   		 		# 		end
   		 		# 	end
   		 		# end
          if row["Precedence"].present? && row["Precedence Name"].present?
            precedence_name = row["Precedence Name"]
            row["Precedence"].split("/").collect(&:strip).each_with_index do |value, index|
                precedence.merge!({"#{value}" => index})
            end

            precedence_hash["#{precedence_name}_precedence"] = precedence
          end

   		 		
   		 		# Code for assigning functional and physical precedence ends

   		 		# Code for End Row Starts

        	if (row["ID"] == "End Rule")
        		test_rule_hash[:tests] = rule_hash
            test_rule_hash.merge!(precedence_hash)
        		# test_rule_hash.merge!("functional_precedence": functional_precedence, "Physical_precedence": physical_precedence)
        		# puts test_rule_hash.to_json
        		# Creation of test rule in category grading rule starts
						test_rule = TestRule.find_or_create_by(rules: test_rule_hash)
						Category.where("id in (?)", category_ids).each do |category|
							if category.category_grading_rule.present?
								# category.category_grading_rule.update(test_rule_id: test_rule.id)
                CategoryGradingRule.find_or_create_by(category: category, grading_type: grading_type).update(test_rule_id: test_rule.id)
							else
								CategoryGradingRule.create(category_id: category.id, test_rule_id: test_rule.id, grading_type: grading_type)
							end
						end		
        		# Creation of test rule in category grading rule ends

        		category_ids = []
        		rule_hash = Hash.new
        		test_rule_hash = Hash.new
        	end

        	# Code for End Row Ends

        end # data loop ends   
			end # transaction ends
			master_file_upload.update(status: "Completed") if master_file_upload.present?
		rescue
			master_file_upload.update(status: "Error") if master_file_upload.present?
		end
  end

  def self.import_grading_rule(master_file_upload = nil,grading_type = nil)
    begin
    	master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
			ActiveRecord::Base.transaction do
        if master_file_upload.present?
          temp_file = open(master_file_upload.master_file.url)
          file = File.new(temp_file)
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        else
          file = File.new("#{Rails.root}/public/master_files/category_grading_rules.csv") if master_file_upload.nil?
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        end
				headers = data.headers

				categories_size = headers.count { |x| x.include?("Category L") }
				category_ids = []
   		 	rule_array = []
   		 	grading_rule_hash = Hash.new
   		 	grade_precedence = {}
        
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

   		 		# Code for fetching of catgory ids for uniq test andd grading rule ends

   		 		# Code for fetching of forming rule starts
   		 		self.construct_new_grading_rule_array(rule_array, row) if (rule_array.blank? || rule_array.find {|rule| rule[:grade] != row["Grade"]})

   		 		# Code for fetching of forming rule ends

   		 		# Code for assigning functional and physical precedence starts

   		 		if row["Grade Precedence"].present? && row["Grade"].present?
 		 				grade_precedence.merge!({"#{row["Grade"]}" =>	 row["Grade Precedence"]})
   		 		end

   		 		
   		 		# Code for assigning functional and physical precedence ends

   		 		# Code for End Row Starts

        	if (row["Grade Precedence"] == "End")
        		grading_rule_hash[:grade_rules] = rule_array
        		grading_rule_hash.merge!("grade_precedence": grade_precedence)
        		# puts grading_rule_hash.to_json
        		# Creation of test rule in category grading rule starts
							grading_rule = GradingRule.find_or_create_by(rules: grading_rule_hash)
							Category.where("id in (?)", category_ids).each do |category|
								if category.category_grading_rule.present?
									# category.category_grading_rule.update(grading_rule_id: grading_rule.id , grading_type: grading_type)
                  CategoryGradingRule.find_or_create_by(category: category, grading_type: grading_type).update(grading_rule_id: grading_rule.id)
								else
									CategoryGradingRule.create(category: category, grading_rule_id: grading_rule.id , grading_type: grading_type)
								end
							end
        		# Creation of test rule in category grading rule ends

        		category_ids = []
        		rule_array = []
        		grading_rule_hash = Hash.new
        	end

        	# Code for End Row Ends

        end # data loop ends
			end # transaction ends
			master_file_upload.update(status: "Completed") if master_file_upload.present?
    rescue
      master_file_upload.update(status: "Error") if master_file_upload.present?
		end
  end


  def self.construct_new_test_rule_hash(rule_hash, row)
  	if ((row["ID"].present?) && (row["ID"] != "End Rule"))
  		rule_hash[row["ID"]] = {"test_type": row["Test Type"].to_s, "test": row["Test"].to_s, "picture": (row["Picture"] == "Yes" ? true : false), 
	  													"annotation": (row["Annotation"] == "Yes" ? true : false),
	  													"annotations": (row["Annotations"].present? ? row["Annotations"].split("/").collect(&:strip) : []),
	  													"annotation_label": row["Annotation Label"].to_s,
	   		 											"picture_labels": (row["Picture Labels"].present? ? row["Picture Labels"].split("/").collect(&:strip) : []),
	  													options: [{"value": row["Options"].to_s,"route": row["Route"].to_s, "output": row["Output"].to_s, 
	  																		 "picture": (row["Picture"] == "Yes" ? true : false), "annotation": (row["Annotation"] == "Yes" ? true : false),
   		 																	 "annotation_label": row["Annotation Label"].to_s, "annotations": (row["Annotations"].present? ? row["Annotations"].split("/").collect(&:strip) : []),
   		 																	 "picture_labels": (row["Picture Labels"].present? ? row["Picture Labels"].split("/").collect(&:strip) : []) }] } if (row["ID"] != "End")
	  	rule_hash["End"] = {"test_type":"End"} if (row["ID"] == "End")
  	end
  end

  def self.construct_new_grading_rule_array(rule_array, row)
  	if ((row["Grade Precedence"].present?) && (row["Grade Precedence"] != "End"))
  		test_groups = []
  		test_headers = ["Item Condition",	"Functional",	"Physical",	"Packaging", "Accessories"]
  		test_headers.each do |test_header|  			
  			test_groups << {"test": test_header, "answers": row[test_header].split("/").collect(&:strip)} if row[test_header].present?
  		end
  		
  		rule_array << {"grade": row["Grade"], "test_groups": test_groups} if (row["ID"] != "End")
  	end
	  rule_array << [{"grade":"End"}] if (row["Grade Precedence"] == "End")
  end

end
