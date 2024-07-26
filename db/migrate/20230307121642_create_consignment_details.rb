class CreateConsignmentDetails < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_details do |t|
      t.integer :client_id
      t.integer :user_id
      t.string :inward_location
      t.string :reverse_logistic_partner
      t.string :gate_pass_number
      t.string :po_number
      t.string :invoice_number
      t.date :invoice_date
      t.string :supplier
      t.string :referance_document_number
      t.string :reverse_dispatch_document_number
      t.integer :total_boxes

      t.timestamps
    end
  end
end
