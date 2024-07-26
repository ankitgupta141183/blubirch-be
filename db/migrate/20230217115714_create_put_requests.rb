class CreatePutRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :put_requests do |t|
      t.integer  :distribution_center_id
      t.string   :request_id
      t.integer  :request_type
      t.integer  :put_away_reason
      t.integer  :pick_up_reason
      t.integer  :assignee_id
      t.integer  :status
      t.integer  :sequence
      t.datetime :completed_at
      
      t.timestamps
    end
  end
end
