class AddLookupColumnsToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :return_type_id, :integer
    add_column :return_items, :channel_id, :integer
    add_column :return_items, :return_reason_id, :integer
    add_column :return_items, :return_sub_reason_id, :integer
    add_column :return_items, :return_request_sub_type_id, :integer
    add_column :return_items, :item_location_id, :integer
    add_column :return_items, :serial_number, :string
    add_column :return_items, :reference_document, :string
    add_column :return_items, :reference_document_number, :string
    add_column :return_items, :sku_description, :string
    add_column :return_items, :details, :jsonb
    remove_column :return_items, :invoice_number
    add_index :return_items, :return_type_id
    add_index :return_items, :channel_id
    add_index :return_items, :return_reason_id
    add_index :return_items, :return_sub_reason_id
    add_index :return_items, :return_request_sub_type_id
    add_index :return_items, :item_location_id
    add_index :return_items, :serial_number
    add_index :return_items, :reference_document
    add_index :return_items, :reference_document_number
    add_index  :return_items, :details, using: :gin
  end
end
