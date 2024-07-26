class AddInternalReturnColumnsToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :type_of_incident_or_damage, :string
    add_column :return_items, :type_of_incident_or_damage_id, :integer
    add_column :return_items, :type_of_loss, :string
    add_column :return_items, :type_of_loss_id, :integer
    add_column :return_items, :estimated_loss, :float
    add_column :return_items, :salvage_value, :string
    add_column :return_items, :salvage_value_id, :string
    add_column :return_items, :incident_date, :datetime
    add_column :return_items, :incident_location, :string
    add_column :return_items, :vendor_responsible, :string
    add_column :return_items, :vendor_responsible_id, :integer
    add_column :return_items, :incident_report_number, :string
    add_index :return_items, :type_of_incident_or_damage_id
    add_index :return_items, :type_of_loss_id
    add_index :return_items, :salvage_value_id
    add_index :return_items, :vendor_responsible_id
  end
end
