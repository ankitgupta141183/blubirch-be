class CreateClientCategoryGradingRules < ActiveRecord::Migration[6.0]
  def change
    create_table :client_category_grading_rules do |t|
      t.integer :client_category_id
      t.integer :test_rule_id
      t.integer :grading_rule_id      
      t.string :grading_type
      t.datetime :deleted_at
      t.timestamps
    end
      add_index :client_category_grading_rules, :client_category_id
  end
end
