class CreatePackagingBoxes < ActiveRecord::Migration[6.0]
  def change
    create_table :packaging_boxes do |t|
    	t.integer :distribution_center_id
			t.integer :user_id
			t.string :box_number
			t.datetime :deleted_at
      t.jsonb :details

      t.timestamps
    end
    add_index :packaging_boxes, :user_id
    add_index :packaging_boxes, :distribution_center_id
  end
end
