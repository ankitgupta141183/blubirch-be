class AddColumIntoRedeploy < ActiveRecord::Migration[6.0]
  def change
  	add_column :redeploys, :vendor, :string
  	rename_column :redeploys, :destination, :destination_code
  	rename_column :redeploys, :source, :source_code
  	add_reference :redeploys, :redeploy_order, index: true
  	add_column :repairs, :serial_number, :string
  end
end
