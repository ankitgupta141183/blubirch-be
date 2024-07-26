class ClientConfiguration < ApplicationRecord

	acts_as_paranoid
	belongs_to :client, optional: true 

	def self.import
		file = File.new("#{Rails.root}/public/master_files/client_configurations.csv") if file.nil?
		CSV.foreach(file.path, headers: true) do |row|
			client_configuration = self.where(key: row[0].try(:strip), code: row[1].try(:strip)).first
			if client_configuration.present?
				client_configuration.update(key: row[0].try(:strip), code: row[1].try(:strip), value: row[2].strip)
			else
				self.create(key: row[0].try(:strip), code: row[1].try(:strip), value: row[2].strip)
			end
		end
	end

end
