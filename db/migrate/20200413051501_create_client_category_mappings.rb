class CreateClientCategoryMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :client_category_mappings do |t|
      t.integer :category_id
      t.integer :client_category_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :client_category_mappings, :category_id
    add_index :client_category_mappings, :client_category_id
  end
end
