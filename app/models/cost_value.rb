class CostValue < ApplicationRecord
	acts_as_paranoid
	def self.import(file)
		CSV.foreach(file.path, headers: true) do |row|
			CostValue.create! row.to_hash
		end
	end
end
