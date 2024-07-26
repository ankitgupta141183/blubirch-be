class CreateForwardSyncedRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :forward_synced_requests do |t|
      t.jsonb :payload
      t.string :document_number
      t.string :status
      t.timestamps
    end
  end
end
