class CreateConsignmentBoxImages < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_box_images do |t|
      t.references :consignment_information
      t.string :box_number
      t.boolean :is_damaged, default: false
      t.integer :damaged_box_items
      t.json :damaged_images
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
