class AddClientCategoryToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_inventory_informations, :client_category_id, :integer
    add_column :return_inventory_informations, :client_sku_master_id, :integer
    add_column :return_inventory_informations, :category_name, :string
    add_index :return_inventory_informations, :client_category_id
    add_index :return_inventory_informations, :client_sku_master_id
    add_column :return_items, :client_category_id, :integer
    add_column :return_items, :client_sku_master_id, :integer
    add_column :return_items, :category_name, :string
    add_index :return_items, :client_category_id
    add_index :return_items, :client_sku_master_id
  end
end
