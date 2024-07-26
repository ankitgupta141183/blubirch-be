class CreateLiquidations < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidations do |t|
    	t.integer :inventory_id
    	t.string :tag_number
    	t.integer :client_sku_master_id
    	t.string :sku_code
    	t.text :item_description
    	t.string :sr_number
    	t.string :location
    	t.string :brand
    	t.string :grade
    	t.string :vendor_code
    	t.integer :distribution_center_id
    	t.jsonb :details
    	t.integer :liquidation_order_id
    	t.string :lot_name
    	t.float :mrp
    	t.float :map
    	t.integer :status_id
    	t.string :status
    	t.float :sales_price
    	t.datetime :deleted_at
    	t.timestamps		
    end
  end
end