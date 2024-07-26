class AddOwnLabelColumnToCustomerReturnReason < ActiveRecord::Migration[6.0]
  def change
    add_column :customer_return_reasons, :own_label, :boolean, default: true
  end
end
