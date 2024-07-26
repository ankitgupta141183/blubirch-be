class CreateReapairHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :reapair_histories do |t|
    	t.integer :repair_id
    	t.integer :status_id
    	t.jsonb :details
    	t.datetime :deleted_at
      t.timestamps
    end
  end
end
