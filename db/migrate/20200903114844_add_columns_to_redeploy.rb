class AddColumnsToRedeploy < ActiveRecord::Migration[6.0]
  def change
    add_column :redeploys, :client_id, :integer
    add_column :redeploys, :client_tag_number, :string
    add_column :redeploys, :toat_number, :string
    add_column :redeploys, :aisle_location, :string
    add_column :redeploys, :item_price, :float
    add_column :redeploys, :serial_number_2, :string
  end
end
