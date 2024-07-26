class AddColumnToPurchaseOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :purchase_orders, :deleted_at, :datetime
  end
end
