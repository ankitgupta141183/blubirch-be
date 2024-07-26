class CreateDispositionRules < ActiveRecord::Migration[6.0]
  def change
    create_table :disposition_rules do |t|
      t.integer :category_id
      t.integer :brand_id
      t.integer :model_id
      t.integer :rule_id

      t.timestamps
    end
  end
end
