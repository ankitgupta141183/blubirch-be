class CreateRedeploys < ActiveRecord::Migration[6.0]
  def change
    create_table :redeploys do |t|
			t.integer :distribution_center_id
			t.references :inventory
			t.string :tag_number
			t.string :sku_code
			t.text :item_description
			t.string :source
			t.string :destination
			t.jsonb :details
			t.integer :status_id
			t.text :pending_destination_remarks
			t.string :status
			t.string :sr_number
			t.string :brand
			t.string :grade
			t.string :serial_number
			t.datetime :deleted_at
      t.timestamps
    end
  end
end