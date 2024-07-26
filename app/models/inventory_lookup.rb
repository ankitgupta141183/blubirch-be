class InventoryLookup < ApplicationRecord
  scope :active,    -> { where(is_active: true) }
  scope :mandatory, -> { where(is_mandatory: true) }

  def self.import_inventory_lookups
    file = File.new("#{Rails.root}/public/master_files/inventory_lookups.csv")
    CSV.foreach(file.path, headers: true) do |row|
      inventory_lookup = self.find_or_initialize_by(name: row['Name']&.strip)

      active = (row['Active'].to_i == 1) ? true : false
      mandatory = (row['Mandatory'].to_i == 1) ? true : false

      inventory_lookup.update(original_name: row['Original Name']&.strip, is_active: active, is_mandatory: mandatory)
    end
  end
end
