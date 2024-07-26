class AddColumnToPosInvoice < ActiveRecord::Migration[6.0]
  def change
    add_column :pos_invoices, :deleted_at, :datetime
  end
end
