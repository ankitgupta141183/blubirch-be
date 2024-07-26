class CreatePendingDispositionHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :pending_disposition_histories do |t|
      t.integer :pending_disposition_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
