class AddPositionToCustomerReturnReason < ActiveRecord::Migration[6.0]
  def change
    add_column :customer_return_reasons, :position, :integer
  end
end
