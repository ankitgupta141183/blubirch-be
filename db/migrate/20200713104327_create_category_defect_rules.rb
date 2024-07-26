class CreateCategoryDefectRules < ActiveRecord::Migration[6.0]
  def change
    create_table :category_defect_rules do |t|
    	t.integer :client_category_id
      t.integer :defect_rule_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :category_defect_rules, :client_category_id
  end
end
