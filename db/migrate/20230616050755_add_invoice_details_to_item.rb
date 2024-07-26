class AddInvoiceDetailsToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :sales_invoice_date, :datetime
    add_column :items, :installation_date, :datetime
    add_column :items, :purchase_invoice_date, :datetime
  end
end
