class AddReturnInventoryInformationIdToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :return_inventory_information_id, :integer
    add_index :return_items, :return_inventory_information_id
    add_column :return_items, :location_id, :string
  end
end
