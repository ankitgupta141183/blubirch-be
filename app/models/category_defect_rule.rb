class CategoryDefectRule < ApplicationRecord
	acts_as_paranoid
	belongs_to :defect_rule, optional: true
	belongs_to :client_category

	  def self.import(file = nil)  	
	    begin
	    	
		ActiveRecord::Base.transaction do

			if (!file.present?)
				file = File.new("#{Rails.root}/public/master_files/defect_rules.csv")
			end
			data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
			headers = data.headers

			categories_size = headers.count { |x| x.include?("Category L") }
			category_ids = []
		 	defect_hash = Hash.new
		 	test_rule_hash = Hash.new
		 	precedence = {}
		 	condition = []
		 	definition = []
		 	persistent_defect_name = ""
	        
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
			              last_category = last_category.descendants.where(name: individual_category).last
			            end
	          		end
	   		 		category_ids << last_category.try(:id)	        	
	   		 	end

	   		 		
	   		 	defect_name = row["Defect"]
	   		 	if defect_name.present?
	   		 		persistent_defect_name = defect_name
	   		 		if defect_hash[persistent_defect_name].nil?
	   		 			defect_hash[persistent_defect_name] = []
	   		 		else
	   		 			defect_hash[persistent_defect_name] << row["Type"]
	   		 		end
	   		 	else
	   		 		defect_hash[persistent_defect_name] << row["Type"]
	   		 	end


	   		 		

	        end # data loop ends   

	       
	        rule=DefectRule.create(rules:defect_hash)
	        
	        category_ids.each do |c|
	        	CategoryDefectRule.create(client_category_id: c, defect_rule_id: rule.id ) if c.present?
	        end
		end # transaction ends
			#master_file_upload.update(status: "Completed")
		rescue
			#master_file_upload.update(status: "Error")
		end
	end
end
