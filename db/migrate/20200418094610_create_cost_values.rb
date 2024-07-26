class CreateCostValues < ActiveRecord::Migration[6.0]
  def change
    create_table :cost_values do |t|
      t.integer :category_id
      t.integer :cost_attribute_id
      t.string :brand
      t.string :model
      t.string :value

      t.timestamps
    end
    add_index :cost_values, :category_id
    add_index :cost_values, :cost_attribute_id
  end
end
