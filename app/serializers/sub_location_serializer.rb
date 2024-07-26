class SubLocationSerializer < ActiveModel::Serializer
  include Utils::Formatting
  # belongs_to :distribution_center

  attributes :id, :distribution_center_id, :distribution_center, :name, :code, :location_type, :created_at, :last_updated
  attribute :rules, if: :show_rules?

  def distribution_center
    object.distribution_center&.code
  end
  
  def location_type
    object.location_type&.titleize
  end
  
  def created_at
    format_ist_time(object.created_at)
  end
  
  def last_updated
    format_ist_time(object.updated_at)
  end
  
  def rules
    rules = []
    rules << "Category (#{object.category.count})" if object.category.present?
    rules << "Brand (#{object.brand.count})" if object.brand.present?
    rules << "Grade (#{object.grade.count})" if object.grade.present?
    rules << "Disposition (#{object.disposition.count})" if object.disposition.present?
    rules << "Return Reason (#{object.return_reason.count})" if object.return_reason.present?
    if rules.blank?
      return "N/A"
    else
      return rules.join(', ')
    end
  end
  
  def show_rules?
    @instance_options[:rules]
  end

end
