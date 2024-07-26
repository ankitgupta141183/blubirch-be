class CreateOutboundDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :outbound_documents do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id 
      t.integer :status_id
      t.string :status
      t.integer :source_id 
      t.integer :destination_id
      t.integer :gatepass_number
      t.string :client_gatepass_number
      t.datetime :document_date
      t.string :source_code
      t.string :source_address
      t.string :source_city      
      t.string :source_state
      t.string :source_country
      t.string :source_pincode
      t.string :destination_code
      t.string :destination_address
      t.string :destination_city
      t.string :destination_state
      t.string :destination_country
      t.string :destination_pincode
      t.jsonb :details
      t.boolean :is_forward, default:true
      t.string :document_type
      t.integer :document_type_id
      t.string :batch_number
      t.string :synced_response
      t.datetime :synced_response_received_at
      t.boolean :is_error_response_received, default: false
      t.boolean :is_error, default: false
      t.string :assigned_username
      t.datetime :assigned_at
      t.boolean :assigned_status, default: false
      t.integer :assigned_user_id
      t.integer :total_quantity
      t.datetime :document_submitted_time
      t.string :gi_batch_number
      t.datetime :deleted_at
      t.integer :master_data_input_id

      t.timestamps
    end

    add_index :outbound_documents, :distribution_center_id
    add_index :outbound_documents, :client_id
    add_index :outbound_documents, :user_id
    add_index :outbound_documents, :status_id
    add_index :outbound_documents, :client_gatepass_number
    add_index :outbound_documents, :source_id
    add_index :outbound_documents, :destination_id
    add_index :outbound_documents, :document_type_id
    add_index :outbound_documents, :assigned_user_id
    add_index :outbound_documents, :master_data_input_id
  end
end
