class CreateBomMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :bom_mappings do |t|
      t.references :client_sku_master
      t.integer :bom_article_id
      t.string :sku_code
      t.integer :quantity
      t.string :uom
      t.integer :uom_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
