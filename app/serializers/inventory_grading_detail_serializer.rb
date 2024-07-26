class InventoryGradingDetailSerializer < ActiveModel::Serializer

	#belongs_to :inventory
  attributes :id, :tag_number, :assisted_grading, :ai_grading, :ai_discrepancy, :ai_discrepancy_data
  #attributes :id, :distribution_center_id, :inventory, :inventory_id, :user_id, :grade_id , :details,  :created_at, :updated_at, :deleted_at, :packaging_status, :physical_status

  def tag_number
    object.inventory.tag_number
  end

  def assisted_grading
    object.inventory.grade
  end

  def ai_grading
    object.grade.original_code
  end 

  def ai_discrepancy
    assisted_grading == ai_grading
  end

  def ai_discrepancy_data
    object.details["final_grading_result"]['ai_discrepancy'] rescue []
  end

end
