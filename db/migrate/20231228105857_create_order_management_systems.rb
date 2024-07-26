class CreateOrderManagementSystems < ActiveRecord::Migration[6.0]
  def change
    reversible do |migration|
      migration.up do
        execute %q(CREATE EXTENSION IF NOT EXISTS "uuid-ossp")

        create_table :order_management_systems do |t|
          t.uuid :batch_number, null: false, default: -> { "uuid_generate_v4()" }
          t.date :rrd_creation_date, index: true
          t.string :reason_reference_document_no
          t.references :billing_location, index: true
          t.jsonb :billing_location_details, default: {}
          t.references :receiving_location, index: true
          t.jsonb :receiving_location_details, default: {}
          t.references :vendor, index: true
          t.jsonb :vendor_details, default: {}
          t.decimal :amount
          t.string :status, index: true
          t.string :order_reason
          t.boolean :has_payment_terms, index: true, :default => false
          t.string :disposition, index: true
          t.integer :disposition_id 
          t.string :oms_type, index: true
          t.string :order_type, index: true
          t.jsonb :payment_term_details, default: {}
          t.string :remarks
          t.text :terms_and_conditions
          t.jsonb :shipping_location_details, default: {}
          t.jsonb :details, default: {}
          t.timestamps
        end

        add_index :order_management_systems, :batch_number, unique: true
      end

      migration.down do
        execute %q(DROP TABLE IF EXISTS "order_management_systems")
        execute %q(DROP EXTENSION IF EXISTS "uuid-ossp")
      end
    end
  end
end
