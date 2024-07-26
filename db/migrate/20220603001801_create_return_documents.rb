class CreateReturnDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :return_documents do |t|
      t.integer :document_type_id
      t.string :document_type
      t.string :client_gatepass_number
      t.datetime :dispatch_date
      t.integer :client_id
      t.integer :user_id
      t.integer :status_id
      t.string :status
      t.integer :distribution_center_id
      t.boolean :is_forward
      t.integer :destination_id
      t.string :destination_code
      t.string :destination_address
      t.string :destination_city
      t.string :destination_state
      t.string :destination_country
      t.string :gatepass_number
      t.string :source_code
      t.integer :source_id
      t.string :source_address
      t.string :source_city
      t.string :source_state
      t.string :source_country
      t.string :batch_number
      t.string :idoc_number
      t.string :idoc_created_at
      t.integer :master_data_input_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :return_documents, :document_type_id
    add_index :return_documents, :client_id
    add_index :return_documents, :user_id
    add_index :return_documents, :status_id
    add_index :return_documents, :source_id
    add_index :return_documents, :destination_id
    add_index :return_documents, :master_data_input_id
  end
end
