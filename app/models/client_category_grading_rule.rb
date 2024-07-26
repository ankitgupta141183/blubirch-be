class ClientCategoryGradingRule < ApplicationRecord
  
  belongs_to :test_rule, optional: true
  belongs_to :grading_rule, optional: true
  belongs_to :client_category

  acts_as_paranoid

  def self.import_client_test_rule_trial(master_file_upload = nil)    
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
      client_id = master_file_upload.client_id if master_file_upload.present?
      ActiveRecord::Base.transaction do
        if master_file_upload.present?
          data = CSV.read(master_file_upload.master_file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        else
          file = File.new("#{Rails.root}/public/master_files/demo_category_grading_tests_trial.csv") if master_file_upload.nil?
          if (Client.all.size == 1)
            client_id = Client.first.id
          else
            raise "Client Information not present"
          end
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        end
        headers = data.headers

        categories_size = headers.count { |x| x.include?("Category L") }
        category_ids = []
        rule_hash = Hash.new
        test_rule_hash = Hash.new
        functional_precedence = {}
        physical_precedence = {}
        
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
                last_category = ClientCategory.where(client_id: client_id, code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
              else
                last_category = last_category.descendants.where(name: individual_category).last if last_category
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
                  rule_hash[rule_ref][:options] << { "value": (row["Options"].present? ? row["Options"].strip.to_s : ""),"route": (row["Route"].present? ? row["Route"].strip.to_s : ""), "output": (row["Output"].present? ? row["Output"].strip.to_s : ""),
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

          if row["Test Type"] == "Functional Precedence"
            if row["Test"].present?
              row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
                functional_precedence.merge!({"#{value}" => index})
              end
            end
          end

          if row["Test Type"] == "Physical Precedence"
            if row["Test"].present?
              row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
                physical_precedence.merge!({"#{value}" => index})
              end
            end
          end

          
          # Code for assigning functional and physical precedence ends

          # Code for End Row Starts

          if (row["ID"] == "End Rule")
            test_rule_hash[:tests] = rule_hash
            test_rule_hash.merge!("functional_precedence": functional_precedence, "Physical_precedence": physical_precedence)
            # puts test_rule_hash.to_json
            # Creation of test rule in category grading rule starts
            test_rule = TestRule.create(rules: test_rule_hash)
            category_ids = category_ids.compact
            ClientCategory.where("id in (?)", category_ids).each do |client_category|
              if client_category.client_category_grading_rule.present?
                client_category.client_category_grading_rule.update(test_rule_id: test_rule.id)
              else
                ClientCategoryGradingRule.create(client_category_id: client_category.id, test_rule_id: test_rule.id)
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



  def self.import_client_test_rule(master_file_upload = nil, grading_type = nil, path = nil)    
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
      client_id = master_file_upload.client_id if master_file_upload.present?
      ActiveRecord::Base.transaction do
        if master_file_upload.present?
          temp_file = open(master_file_upload.master_file.url)
          file = File.new(temp_file)
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        else
          file = File.new(path) if master_file_upload.nil?
          if (Client.all.size == 1)
            client_id = Client.first.id
          else
            raise "Client Information not present"
          end
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
                last_category = ClientCategory.where(client_id: client_id, code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
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
                  rule_hash[rule_ref][:options] << { "value": (row["Options"].present? ? row["Options"].strip.to_s : ""),"route": (row["Route"].present? ? row["Route"].strip.to_s : ""), "output": (row["Output"].present? ? row["Output"].strip.to_s : ""),
                                                     "picture": (row["Picture"] == "Yes" ? true : false), 
                                                     "annotation": (row["Annotation"] == "Yes" ? true : false),
                                                     "annotation_label": (row["Annotation Label"].present? ? row["Annotation Label"].strip.to_s : ""),
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
          #   if row["Test"].present?
          #     row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
          #       functional_precedence.merge!({"#{value}" => index})
          #     end
          #   end
          # end

          # if row["Test Type"] == "Physical Precedence"
          #   if row["Test"].present?
          #     row["Test"].split("/").collect(&:strip).each_with_index do |value, index|
          #       physical_precedence.merge!({"#{value}" => index})
          #     end
          #   end
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
            # puts test_rule_hash.to_json
            # Creation of test rule in category grading rule starts
            test_rule = TestRule.find_or_create_by(rules: test_rule_hash)
            category_ids = category_ids.compact
            ClientCategory.where("id in (?)", category_ids).each do |client_category|
              if grading_type.present? && client_category.client_category_grading_rules.where(grading_type:grading_type).first.present?
                client_category.client_category_grading_rules.where(grading_type:grading_type).first.update(test_rule_id: test_rule.id)
                # ClientCategoryGradingRule.find_or_create_by(client_category: client_category, grading_type: grading_type).update(test_rule_id: test_rule.id)
              else
                ClientCategoryGradingRule.create(client_category_id: client_category.id, test_rule_id: test_rule.id, grading_type: grading_type)
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
    rescue ActiveRecord::StatementInvalid => e
      master_file_upload.update(status: "Error") if master_file_upload.present?
    end
  end


  def self.import_client_grading_rule(master_file_upload = nil,grading_type = nil, path = nil)
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
      client_id = master_file_upload.client_id if master_file_upload.present?
      ActiveRecord::Base.transaction do
        if master_file_upload.present?
          temp_file = open(master_file_upload.master_file.url)
          file = File.new(temp_file)
          data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        else
          file = File.new(path) if master_file_upload.nil?
          if (Client.all.size == 1)
            client_id = Client.first.id
          else
            raise "Client Information not present"
          end
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
                last_category = ClientCategory.where(client_id: client_id, code: "l#{index+1}_#{individual_category.parameterize.underscore}").last
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
            grade_precedence.merge!({"#{row["Grade"]}" =>  row["Grade Precedence"]})
          end

          
          # Code for assigning functional and physical precedence ends

          # Code for End Row Starts

          if (row["Grade Precedence"] == "End")
            grading_rule_hash[:grade_rules] = rule_array
            grading_rule_hash.merge!("grade_precedence": grade_precedence)
            # puts grading_rule_hash.to_json
            # Creation of test rule in category grading rule starts
              grading_rule = GradingRule.find_or_create_by(rules: grading_rule_hash)

              category_ids = category_ids.compact
              ClientCategory.where("id in (?)", category_ids).each do |client_category|
                if grading_type.present? && client_category.client_category_grading_rules.where(grading_type:grading_type).first.present?
                  client_category.client_category_grading_rules.where(grading_type:grading_type).first.update(grading_rule_id: grading_rule.id)
                  # ClientCategoryGradingRule.find_or_create_by(client_category: client_category, grading_type: grading_type).update(grading_rule_id: grading_rule.id)
                else
                  ClientCategoryGradingRule.create(client_category: client_category, grading_rule_id: grading_rule.id , grading_type: grading_type)
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
      rule_hash[row["ID"]] = {"test_type": (row["Test Type"].present? ? row["Test Type"].strip.to_s : ""), "test": (row["Test"].present? ? row["Test"].strip.to_s : ""), "picture": (row["Picture"] == "Yes" ? true : false), 
                              "annotation": (row["Annotation"] == "Yes" ? true : false),
                              "annotations": (row["Annotations"].present? ? row["Annotations"].split("/").collect(&:strip) : []),
                              "annotation_label": (row["Annotation Label"].present? ? row["Annotation Label"].strip.to_s : ""),
                              "picture_labels": (row["Picture Labels"].present? ? row["Picture Labels"].split("/").collect(&:strip) : []),
                              options: [{"value": (row["Options"].present? ? row["Options"].strip.to_s : ""),"route": (row["Route"].present? ? row["Route"].strip.to_s : ""), "output": (row["Output"].present? ? row["Output"].strip.to_s : ""),
                                         "picture": (row["Picture"] == "Yes" ? true : false), "annotation": (row["Annotation"] == "Yes" ? true : false),
                                         "annotation_label": (row["Annotation Label"].present? ? row["Annotation Label"].strip.to_s : ""), "annotations": (row["Annotations"].present? ? row["Annotations"].split("/").collect(&:strip) : []),
                                         "picture_labels": (row["Picture Labels"].present? ? row["Picture Labels"].split("/").collect(&:strip) : []) }] } if (row["ID"] != "End")
      rule_hash["End"] = {"test_type":"End"} if (row["ID"] == "End")
    end
  end

  def self.construct_new_grading_rule_array(rule_array, row)
    if ((row["Grade Precedence"].present?) && (row["Grade Precedence"] != "End"))
      test_groups = []
      test_headers = ["Item Condition", "Functional", "Physical Condition", "Packaging Condition", "Accessories"]
      test_headers.each do |test_header|        
        test_groups << {"test": test_header, "answers": row[test_header].split("/").collect(&:strip)} if row[test_header].present?
      end
      
      rule_array << {"grade": row["Grade"], "test_groups": test_groups} if (row["ID"] != "End")
    end
    rule_array << {"grade":"End"} if (row["Grade Precedence"] == "End")
  end


  def self.calculate_grade(client_category_id,final_grading_result,grading_type)
    begin
      processed_grading_result = {}
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
      final_grade = "Not Tested" if final_grade.blank?
      return final_grade , processed_grading_result , nil
    rescue ActiveRecord::StatementInvalid => e
      return nil , nil , "Error in calculation of grade => #{e.message}"
    end
  end

end