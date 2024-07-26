class AddDetailsColumnToReturnInventoryInformations < ActiveRecord::Migration[6.0]
  def change
    add_column :return_inventory_informations, :details, :jsonb
    add_column :return_inventory_informations, :available_quantity, :integer
    add_column :return_inventory_informations, :returned_quantity, :integer, default: 0
    add_index  :return_inventory_informations, :details, using: :gin
  end
end
