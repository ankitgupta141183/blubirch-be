class AddIndexOnDocumentNumberForwardSyncedRequest < ActiveRecord::Migration[6.0]
  def change
    add_index :forward_synced_requests, :document_number
    add_column :push_inbounds, :batch_number, :string
    add_index :push_inbounds, :batch_number
  end
end
