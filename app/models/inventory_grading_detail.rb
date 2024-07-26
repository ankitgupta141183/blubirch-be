class InventoryGradingDetail < ApplicationRecord
    acts_as_paranoid
    belongs_to :inventory
    belongs_to :distribution_center
    belongs_to :user, optional: true
    belongs_to :grade, class_name: "LookupValue", foreign_key: :grade_id


    def grade_summary
        {
            grade: item_grade,
            packaging_status: packaging_status,
            packaging_image_annotations: packaging_image_annotations,
            item_condition: item_condition,
            phyisical_status: phyisical_status , 
            physical_image_annotations: physical_image_annotations,
            functional_qa: functional_qa,
            accessories: accessories
        }
    end

    #InventoryGradingDetail.calculate_weightage_grade(0.8)
    def self.calculate_weightage_grade(weightage)
      if weightage.to_f >= 1
        return 'Open Box'
      elsif weightage.to_f >= 0.8 && weightage.to_f < 1
        return 'Very Good'
      elsif weightage.to_f >= 0.1 && weightage.to_f < 0.8
        return 'Good'
      else
        return 'Acceptable'
      end
    end

    def item_grade
        self.inventory.grade rescue ''
    end

    def item_condition
        self.details["final_grading_result"]["Item Condition"].first["value"] rescue ''
    end

    def functional_qa
        self.details["final_grading_result"]["Functional"] rescue []
    end

    def accessories
      self.details["final_grading_result"]["Accessories"] rescue []
    end

    def packaging_status
        self.details["final_grading_result"]["Packaging"].first["value"] rescue ''
    end

    def phyisical_status
        self.details["final_grading_result"]["Item Condition"].first["value"] rescue ''
    end

    def physical_image_annotations
        self.details["final_grading_result"]["Item Condition"][0]["annotations"] rescue []
        # [
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_975613.png"},
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_408250.png"},
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_806338.png"}
    # ]
    end

    def packaging_image_annotations
        self.details["final_grading_result"]["Packaging"][0]["annotations"] rescue []
    #  [
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_975613.png"},
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_408250.png"},
      #   {src: "https://beam-saas-dev.s3.ap-south-1.amazonaws.com/public/uploads/item_806338.png"}
    # ]
    end


    def self.store_grade_inventory(inventory_id,final_grading_result,processed_grading_result,grade,user)

        inventory = Inventory.find(inventory_id)        
        grade_id = LookupValue.where(original_code: grade).last.id rescue nil
        previous_grading_detail = inventory.inventory_grading_details.last rescue nil
        if previous_grading_detail.present?
            previous_grading_detail.update(is_active:false)
        end

        grading_detail = inventory.inventory_grading_details.new(distribution_center_id: inventory.distribution_center_id, user_id: user.id)
        grading_detail.details = {}
        grading_detail.details["processed_grading_result"] = processed_grading_result
        grading_detail.details['final_grading_result'] = final_grading_result
        grading_detail.details["warehouse_inwarding_date"] = Time.now.to_s
        grading_detail.is_active = true
        grading_detail.grade_id = grade_id
        grading_detail.save


    end
end