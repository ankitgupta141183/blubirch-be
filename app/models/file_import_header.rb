class FileImportHeader < ApplicationRecord
	acts_as_paranoid

	def self.import(file = nil)
		file = File.new("#{Rails.root}/public/master_files/file_import_headers.csv") if file.nil?
		CSV.foreach(file.path, headers: true) do |row|
			file_import_header = self.where(name: row["Name"].try(:strip), headers: row["Headers"].try(:strip)).first
			if file_import_header.present?
				file_import_header.update(name: row["Name"].try(:strip), headers: row["Headers"].try(:strip), is_hash: (row[2].try(:strip) == "TRUE") ? true : false)
			else
				self.create(name: row["Name"].try(:strip), headers: row["Headers"].try(:strip), is_hash: (row[2].try(:strip).to_s == "TRUE") ? true : false)
			end
		end
	end

end
