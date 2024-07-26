class AddClientConfigurationColumns < ActiveRecord::Migration[6.0]
  def change
    add_column :client_sku_masters, :attribute_details, :jsonb
    add_column :sku_eans, :mrp, :float
    add_column :sku_eans, :asp, :float
    add_column :sku_eans, :map, :float
    add_column :distribution_centers, :location_head_name, :string
    add_column :distribution_centers, :location_head_email, :string
    add_column :distribution_centers, :location_head_mobile, :string
    add_column :distribution_centers, :master_location_code, :string
    add_column :distribution_centers, :master_location_id, :integer
    add_column :distribution_centers, :master_location_name, :string
    add_index :client_sku_masters, :attribute_details, using: :gin
    add_index :distribution_centers, :master_location_id
  end
end
