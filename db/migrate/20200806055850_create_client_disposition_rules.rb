class CreateClientDispositionRules < ActiveRecord::Migration[6.0]
  def change
    create_table :client_disposition_rules do |t|
      t.integer :client_category_id
      t.integer :brand_id
      t.integer :model_id
      t.integer :rule_id
      t.string :disposition_type
    end
  end
end
