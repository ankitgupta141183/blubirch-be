class LogisticsPartner < ApplicationRecord
	acts_as_paranoid
  has_many :consignments

  include Filterable
	scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}

	def self.create_logistics_partners
		self.create(name: "Gati")
		self.create(name: "TCI Xpress")
		self.create(name: "Merck")
		self.create(name: "Snowman Logistcs")
		self.create(name: "DB Schenker")
	end

end
