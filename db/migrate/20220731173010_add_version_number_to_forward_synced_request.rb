class AddVersionNumberToForwardSyncedRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :forward_synced_requests, :app_version, :string
  end
end
