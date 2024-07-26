class AddColumnToPhysicalInspection < ActiveRecord::Migration[6.0]
  def change
    add_column :physical_inspections, :sub_location_ids, :text
  end
end
