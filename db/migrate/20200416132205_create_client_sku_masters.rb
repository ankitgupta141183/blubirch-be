class CreateClientSkuMasters < ActiveRecord::Migration[6.0]
  def change
    create_table :client_sku_masters do |t|
      t.integer :client_category_id
      t.string :code
      t.jsonb :description
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :client_sku_masters, :client_category_id
  end
end
