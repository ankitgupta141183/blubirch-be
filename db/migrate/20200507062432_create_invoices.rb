class CreateInvoices < ActiveRecord::Migration[6.0]
  def change
    create_table :invoices do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.string :invoice_number
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :invoices, :distribution_center_id
  end
end
