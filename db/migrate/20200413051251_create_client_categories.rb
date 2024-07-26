class CreateClientCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :client_categories do |t|
      t.string :name
      t.string :code
      t.integer :client_id
      t.text :attrs
      t.string :ancestry
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :client_categories, :client_id
    add_index :client_categories, :ancestry
  end
end
