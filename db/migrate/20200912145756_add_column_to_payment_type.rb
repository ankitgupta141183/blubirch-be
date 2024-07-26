class AddColumnToPaymentType < ActiveRecord::Migration[6.0]
  def change
    add_column :payment_types, :deleted_at, :datetime
  end
end
