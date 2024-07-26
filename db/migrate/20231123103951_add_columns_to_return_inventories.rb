class AddColumnsToReturnInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :return_inventories, :payload, :jsonb
    add_column :return_inventories, :headers_data, :jsonb
    add_column :return_inventories, :response_data, :jsonb
  end
end
