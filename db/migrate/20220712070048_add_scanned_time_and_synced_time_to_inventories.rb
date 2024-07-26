class AddScannedTimeAndSyncedTimeToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :synced_time, :string
    add_column :inventories, :scanned_time, :string
  end
end
