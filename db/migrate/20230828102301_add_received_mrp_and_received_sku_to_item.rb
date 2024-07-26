class AddReceivedMrpAndReceivedSkuToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :received_sku, :string
    add_column :items, :received_mrp, :float
  end
end
