class ClientAttributeMaster < ActiveRecord::Base
  
  has_logidze
  acts_as_paranoid

  validates :attr_type, :attr_label, :field_type, presence: true

  include Filterable
  
  scope :filter_by_client_name, -> (name) {joins(:client).where("name ilike ?", "%#{name}%")}
  scope :filter_by_attr_type, -> (attr_type) { where("attr_type ilike ?", "%#{attr_type}%")}
  scope :filter_by_reason, -> (reason) { where("reason ilike ?", "%#{reason}%")}
  scope :filter_by_options, -> (option) { where("options ilike ?", "%#{options}%")}
  scope :filter_by_field_type, -> (field_type) { where("field_type ilike ?", "%#{field_type}%")}
  scope :filter_by_attr_label, -> (attr_label) { where("attr_label ilike ?", "%#{attr_label}%") }

	belongs_to :client


	def self.import_client_attributes(file = nil,client_id = nil)
    if file.present? && client_id.present?
      attributes = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
      file = File.new("#{Rails.root}/public/master_files/attributes.csv") if file.nil?
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end
      attributes = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end
		attributes.each do |attr|
    	attribute = self.where("attr_label = ? and client_id = ?", attr[2].try(:strip), client_id).first
			if attribute.nil?
				self.create(client_id: client_id, attr_type: attr[0].try(:strip), reason: attr[1].try(:strip), attr_label: attr[2].try(:strip), field_type: attr[3].try(:strip), options: attr[4].try(:strip))
			end   	
		end
	end
end
