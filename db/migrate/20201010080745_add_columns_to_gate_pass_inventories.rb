class AddColumnsToGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_pass_inventories, :merchandise_category, :integer
    add_column :gate_pass_inventories, :merch_cat_desc, :string
    add_column :gate_pass_inventories, :line_item, :integer
    add_column :gate_pass_inventories, :document_type, :string
    add_column :gate_pass_inventories, :site_name, :string
    add_column :gate_pass_inventories, :consolidated_gi, :string
    add_column :gate_pass_inventories, :sto_date, :datetime
    add_column :gate_pass_inventories, :group, :integer
    add_column :gate_pass_inventories, :group_code, :string
  end
end
