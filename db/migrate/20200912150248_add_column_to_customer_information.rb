class AddColumnToCustomerInformation < ActiveRecord::Migration[6.0]
  def change
    add_column :customer_informations, :deleted_at, :datetime
  end
end
