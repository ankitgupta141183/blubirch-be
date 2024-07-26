class CreateCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :code
      t.text :attrs
      t.string :ancestry
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :categories, :ancestry
  end
end
