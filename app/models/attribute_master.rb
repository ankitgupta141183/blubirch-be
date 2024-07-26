class AttributeMaster < ActiveRecord::Base

	has_logidze
	acts_as_paranoid
	acts_as_paranoid

  validates :attr_type, :attr_label, :field_type, presence: true


	include Filterable
	scope :filter_by_attr_type, -> (attr_type) { where("attr_type ilike ?", "%#{attr_type}%")}
	scope :filter_by_reason, -> (reason) { where("reason ilike ?", "%#{reason}%")}
	scope :filter_by_attr_label, -> (attr_label) { where("attr_label ilike ?", "%#{attr_label}%")}
	scope :filter_by_field_type, -> (field_type) { where("field_type ilike ?", "%#{field_type}%")}
	scope :filter_by_options, -> (options) { where("options ilike ?", "%#{options}%")}

	def self.import_attributes(file = nil)
		file = File.new("#{Rails.root}/public/master_files/attributes.csv") if file.nil?
		CSV.foreach(file.path, headers: true) do |attr|
			attribute = self.where(attr_label: attr[2].try(:strip)).first
			if attribute.nil?
				self.create(attr_type: attr[0].try(:strip), reason: attr[1].try(:strip), attr_label: attr[2].try(:strip), field_type: attr[3].try(:strip), options: attr[4].try(:strip))
			else
				attribute.update(attr_type: attr[0].try(:strip), reason: attr[1].try(:strip), field_type: attr[3].try(:strip), options: attr[4].try(:strip))
			end   	
		end
	end

end
