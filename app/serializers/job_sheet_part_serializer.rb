class JobSheetPartSerializer < ActiveModel::Serializer

  belongs_to :job_sheet
  attributes :id, :repair_part, :quantity, :images, :part_cost, :repair_part_id, :remarks, :submission_remarks, :amount, :repaired, :details, :created_at, :updated_at

  
  def repair_part
    object.repair_part.name rescue ''
  end

  def repaired
    if object.repaired == true
      return "Yes" 
    else
      return "No"
    end
  end 

  def images
    object.details["images"] rescue ''
  end

  def repair_part_id
    object.repair_part.id rescue ''
  end

  def part_cost
    object.repair_part.price rescue ''
  end

  def remarks
    object.details["remarks"] rescue ''
  end

  def submission_remarks
    object.details["submission_remarks"] rescue ''
  end
 
end
