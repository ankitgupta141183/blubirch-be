class AddColumnsToClientDispositionRules < ActiveRecord::Migration[6.0]
  def change
  	add_column :client_disposition_rules, :name, :string
  	add_column :client_disposition_rules, :client_category_name, :string
  	add_column :client_disposition_rules, :brand_name, :string
  	add_column :client_disposition_rules, :item_model_name, :string
  	add_column :client_disposition_rules, :sku_code, :string
  	add_column :client_disposition_rules, :deleted_at, :datetime
  	add_column :client_disposition_rules, :disposition, :string

  	add_timestamps(:client_disposition_rules)


  end
end
