class ClientDispositionRule < ApplicationRecord
  acts_as_paranoid
  belongs_to :rule ,optional: true
  belongs_to :client_category ,optional: true

  PRECEDENCE = {"E-Waste" => 1,"Liquidation" => 2,"Redeploy" => 3,"Markdown" => 4, "Repair" => 5,"Replacement" => 6,"Insurance" => 7,"RTV" => 8,"Restock" => 9}

  
  # def self.calculate_disposition(client_category_id , inventory_id, inventory)
  #   begin
  #     output_flow = ""
  #     output_disposition = ""
  #     disposition_current_rank = -1
  #     disposition_array = []


  #     rule_name = ""

  #     inventory = inventory.present? ? inventory : Inventory.find(inventory_id)
  #     rule_name_with_cat = ""
  #     rule_name_with_brand = ""
  #     rule_name_with_sku = ""
  #     rule_name = ""

  #     ClientCategory.find(client_category_id).ancestors.each_with_index do |cat, index|

  #       rule_name_with_cat = rule_name + cat.name + " "
  #       rule_name = rule_name_with_cat

  #     end

  #     rule_name_with_cat = rule_name + ClientCategory.find(client_category_id).name + " "
  #     rule_name = rule_name_with_cat

  #     if inventory.details["brand"].present?
  #       rule_name_with_brand = rule_name + inventory.details["brand"] + " "
  #       rule_name = rule_name_with_brand
  #     end

  #     if inventory.details["sku_code"].present?
  #       rule_name_with_sku = rule_name + inventory.details["sku_code"] + " "
  #       rule_name = rule_name_with_sku
  #     end
  #     final_rule_name = ""
  #     rule_name = rule_name.parameterize.underscore

  #     if ClientDispositionRule.where(name:rule_name_with_sku.parameterize.underscore).present?
  #       final_rule_name = rule_name_with_sku.parameterize.underscore
  #     elsif ClientDispositionRule.where(name:rule_name_with_brand.parameterize.underscore).present?
  #       final_rule_name = rule_name_with_brand.parameterize.underscore
  #     elsif ClientDispositionRule.where(name:rule_name_with_cat.parameterize.underscore).present?
  #       final_rule_name = rule_name_with_cat.parameterize.underscore
  #     end

  #     ClientDispositionRule.where(name:final_rule_name).each do |cdr|
          
  #       @rule = cdr.rule
        
  #       rule_definition = @rule.rule_definition["Rule Definition"]
  #       condition = @rule.condition
  #       variable_properties = @rule.rule_definition["Variable Properties"]
  #       temp_variable_array = []

  #       rule_definition.split(' ').each_with_index do |rd, index|       
  #         if index % 2 == 0
  #           temp_variable_array << "#{rd}"
  #         end       
  #       end

  #       temp_variable_array.each do |ts|
  #         eval("#{ts} = false")
  #       end
  #       temp_str = ""

  #       temp_variable_array.each do |ts|
  #         temp_str = "#{ts} = #{condition[ts[1..-1]] == inventory.details[ts[1..-1]]}"
  #         eval("#{ts} = #{condition[ts[1..-1]] == inventory.details[ts[1..-1]]}")
  #       end

  #       temp_variable_array = []
  #       variable_properties_string = ""
  #       variable_properties.split(' ').each_with_index do |vp, index|         
  #         if index % 2 == 0
  #           temp_variable_array << "#{vp}"
  #           variable_properties_string = variable_properties_string + "@#{vp}" + " "
  #           eval("@#{vp} = false")
  #         else
  #           variable_properties_string = variable_properties_string + "#{vp}" + " "
  #         end
  #       end

  #       vp_query_str = ""
  #       temp_variable_array.each do |ts|
  #         vp_query_str = ""
  #         if ts == "Aging"
  #           vp_query_str = "@#{ts} = (Time.now - Time.parse('#{inventory.details[condition["#{ts}-Attr"]]}')).to_i/86400 #{condition["#{ts}-Operator"]}  #{condition["Limit-#{ts}"]}"

  #         else
  #           vp_query_str = "@#{ts} = #{inventory.details[condition["#{ts}-Attr"]]} #{condition["#{ts}-Operator"]} #{condition["Limit-#{ts}"]}"
  #         end
  #         eval(vp_query_str)
          
  #       end
  #       final_string = ""
  #       if rule_definition != "" && variable_properties_string != ""
  #         final_string = rule_definition + "&&" + variable_properties_string
  #       elsif rule_definition != ""
  #         final_string = rule_definition
  #       elsif variable_properties_string != ""
  #         final_string = variable_properties_string
  #       end
        
  #       if eval(final_string)
  #         if ClientDispositionRule::PRECEDENCE[cdr.disposition] > disposition_current_rank
  #           disposition_current_rank == ClientDispositionRule::PRECEDENCE[cdr.disposition]
  #           output_disposition = cdr.disposition
  #           output_flow = @rule.condition["resultant_flow"]
  #         end
  #       end
  #     end

  #     return {disposition:output_disposition, flow: output_flow}
  #   rescue ActiveRecord::StatementInvalid => e
  #     return {disposition:nil, flow: nil ,error:"Error in calculation of disposition => #{e.message}" }
  #   end
   
  # end


  def self.calculate_disposition(return_reason , label, grade)
    cdr = ClientDispositionRule.where(return_reason: return_reason , label: label)
    cdr = cdr.select{|c| c.grade.split(',').include?(grade)} if grade.present?
    if cdr.present?
      if cdr.count > 1
        return {disposition: cdr.max_by(&:grade_precedence).disposition , flow: cdr.max_by(&:grade_precedence).flow_name}
      else
        return {disposition: cdr.last.disposition , flow: cdr.last.flow_name}
      end
    else
      return {disposition: "NA" , flow: "NA"}
    end
  end

end
