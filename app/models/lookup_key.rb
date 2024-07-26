class LookupKey < ApplicationRecord
	
	has_logidze
  acts_as_paranoid
	has_many :lookup_values

  validates :name, :code, presence: true


  # filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%")}
  # filter logic ends

	def self.import(file = nil)
		file = File.new("#{Rails.root}/public/master_files/lookup_keys.csv") if file.nil?
		CSV.foreach(file.path, headers: true) do |row|
			lookup_key = self.where(name: row[0].try(:strip), code: row[1].try(:strip)).first
			if lookup_key.present?
				lookup_key.update(name: row[0].try(:strip), code: row[1].try(:strip))
			else
				self.create(name: row[0].try(:strip), code: row[1].try(:strip))
			end
		end
	end
	
end
