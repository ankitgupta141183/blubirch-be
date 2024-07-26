class AddDeletedAtToPutRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :put_requests, :deleted_at, :datetime
  end
end
