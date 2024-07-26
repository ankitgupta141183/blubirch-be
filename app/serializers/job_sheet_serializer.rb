class JobSheetSerializer < ActiveModel::Serializer

  has_many :job_sheet_parts
  belongs_to :repair
  
  attributes :id, :tentative_grade, :is_active, :repair_id, :created_at, :updated_at

  def tentative_grade
    object.grade.original_code rescue ''
  end

end
