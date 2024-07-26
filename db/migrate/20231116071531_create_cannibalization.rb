class CreateCannibalization < ActiveRecord::Migration[6.0]
  def change
    create_table :cannibalizations do |t|
      t.string :tag_number
      t.string :sku_code
      t.string :item_description
      t.string :ageing
      t.string :uom
      t.string :condition
      t.string :article_type
      t.string :status
      t.string :tote_id

      t.integer :status_id
      t.integer :inventory_id
      t.integer :quantity
      t.integer :distribution_center_id
      t.integer :parent_id
      t.integer :bom_article_id
      t.integer :client_sku_master_id

      t.boolean :is_active

      t.jsonb :details, default: {}

      t.timestamps
    end
  end
end
