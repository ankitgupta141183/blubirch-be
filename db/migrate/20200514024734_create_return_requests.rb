class CreateReturnRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :return_requests do |t|
    	t.integer :distribution_center_id
    	t.integer :client_id
    	t.integer :invoice_id
      t.integer :customer_return_reason_id
      t.string :request_number
      t.jsonb :details
      t.integer :status_id
    	t.datetime :deleted_at

      t.timestamps
    end
    add_index :return_requests, :distribution_center_id
    add_index :return_requests, :client_id
    add_index :return_requests, :status_id
    add_index :return_requests, :customer_return_reason_id
    add_index :return_requests, :invoice_id
  end
end
