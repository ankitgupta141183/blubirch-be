class AddColumnsToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :document_date, :date
    add_column :items, :model, :string
    add_column :items, :category_code, :string
    add_column :items, :category_node, :jsonb
    add_column :items, :sales_price, :float
    add_column :items, :purchase_price, :float
    add_column :items, :gate_pass_number, :string
    add_column :items, :po_number, :string
    add_column :items, :invoice_number, :string
    add_column :items, :invoice_date, :string
    add_column :items, :supplier, :string
    add_column :items, :referance_document_number, :string
  end
end
