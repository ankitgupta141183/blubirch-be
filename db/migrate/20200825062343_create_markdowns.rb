class CreateMarkdowns < ActiveRecord::Migration[6.0]
  def change
    create_table :markdowns do |t|
      t.integer :markdown_order_id
      t.integer :distribution_center_id
      t.integer :inventory_id
      t.string :tag_number
      t.string :sku_code
      t.text :item_description
      t.string :sr_number
      t.string :brand
      t.string :grade
      t.string :vendor
      t.jsonb :details
      t.integer :status_id
      t.string :status
      t.text :destination_remark
      t.text :destination_code
      t.text :disposition_remark
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :markdowns, :inventory_id
    add_index :markdowns, :distribution_center_id
    add_index :markdowns, :markdown_order_id
  end
end
