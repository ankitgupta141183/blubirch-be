class AddIsPickupDoneToPutRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :put_requests, :is_pickup_done, :boolean, default: false
  end
end
