class UpdateColumnIntoRepairTable < ActiveRecord::Migration[6.0]
  def change
  	add_column :repairs, :client_sku_master_id, :integer
  	add_column :repairs, :sku_code, :string
  	add_column :repairs, :item_description, :text
  	add_column :repairs, :sr_number, :string
  	add_column :repairs, :brand, :string
  	add_column :repairs, :grade, :string
    add_column :repairs, :location, :string
  	remove_column :repairs, :approval_required, :boolean
  	remove_column :repairs, :serial_number, :boolean
  end
end
