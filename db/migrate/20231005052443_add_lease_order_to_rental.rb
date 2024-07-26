class AddLeaseOrderToRental < ActiveRecord::Migration[6.0]
  def change
    add_column :rentals, :lease_order_id, :integer
  end
end
