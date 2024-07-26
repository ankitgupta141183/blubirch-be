class ChangeColumnMerchandiseCategoryToStringInGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    change_column :gate_pass_inventories, :merchandise_category, :string
  end
end
