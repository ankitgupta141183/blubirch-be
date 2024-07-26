class CreateCategoryGradingRules < ActiveRecord::Migration[6.0]
  def change
    create_table :category_grading_rules do |t|
      t.integer :category_id
      t.integer :test_rule_id
      t.integer :grading_rule_id      
      t.string :grading_type
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :category_grading_rules, :category_id
  end
end
