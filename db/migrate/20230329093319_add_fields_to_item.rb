class AddFieldsToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :item_issue, :string
    add_column :items, :item_mismatch_status, :string
  end
end
