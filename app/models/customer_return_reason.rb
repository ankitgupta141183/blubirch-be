class CustomerReturnReason < ApplicationRecord

  acts_as_paranoid

  has_many :return_requests
  has_many :invoices, through: :return_requests
  
  validates :name, presence: true

  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_grading_required, -> (grading_required) { where("grading_required = ?", "#{grading_required}")}

  def self.import(file = nil)
    file = File.new("#{Rails.root}/public/master_files/customer_return_reason.csv") if file.nil?
    CSV.foreach(file.path, headers: true) do |row|
      customer_return_reason = self.where(name: row["Name"].try(:strip) ,grading_required: (row["Grading Required"].try(:strip).to_s == "TRUE") ? true : false, own_label: (row["Own Label"].try(:strip).to_s == "TRUE") ? true : false ).first
      if customer_return_reason.nil? 
        self.create(name: row["Name"].try(:strip) ,grading_required: (row["Grading Required"].try(:strip).to_s == "TRUE") ? true : false, own_label: (row["Own Label"].try(:strip).to_s == "TRUE") ? true : false , position: row["Position"].to_i)
      else
        customer_return_reason.update(name: row["Name"].try(:strip) ,grading_required: (row["Grading Required"].try(:strip).to_s == "TRUE") ? true : false, own_label: (row["Own Label"].try(:strip).to_s == "TRUE") ? true : false, position: row["Position"].to_i)
      end
    end
  end

  def document_types
    file_type = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    if self.name == 'Brand Approved DOA'
      document_types = file_type.lookup_values.where(original_code: 'DOA Letter').pluck(:code, :original_code)
    elsif self.name == 'OL NER Approved'
      document_types = [['ner_number', 'NER Number']]
    else
      document_types = file_type.lookup_values.where(original_code: 'Customer Invoice').pluck(:code, :original_code)
    end
  end

  def input_type
    if self.name == 'Brand Approved DOA'
      return "dropdown"
    else
      return "text"
    end
  end

  def min_value
    file_type = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    if self.name == 'Brand Approved DOA'
      document_types = file_type.lookup_values.where(original_code: 'DOA Letter').last.min_value
    elsif self.name == 'OL NER Approved'
      document_types = file_type.lookup_values.where(original_code: 'NER Number').last.min_value
    else
      document_types = file_type.lookup_values.where(original_code: 'Customer Invoice').last.min_value
    end
  end

  def max_value
    file_type = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    if self.name == 'Brand Approved DOA'
      document_types = file_type.lookup_values.where(original_code: 'DOA Letter').last.max_value
    elsif self.name == 'OL NER Approved'
      document_types = file_type.lookup_values.where(original_code: 'NER Number').last.max_value
    else
      document_types = file_type.lookup_values.where(original_code: 'Customer Invoice').last.max_value
    end
  end

  def is_mandatory
    file_type = LookupKey.where(code: "RETURN_REASON_FILE_TYPES").last
    if self.name == 'Brand Approved DOA'
      document_types = file_type.lookup_values.where(original_code: 'DOA Letter').last.is_mandatory
    elsif self.name == 'OL NER Approved'
      document_types = file_type.lookup_values.where(original_code: 'NER Number').last.is_mandatory
    else
      document_types = file_type.lookup_values.where(original_code: 'Customer Invoice').last.is_mandatory
    end
  end
end
