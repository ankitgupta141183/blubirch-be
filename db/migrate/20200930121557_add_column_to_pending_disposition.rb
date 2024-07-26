class AddColumnToPendingDisposition < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_dispositions, :disposition_remark, :text
    add_column :pending_dispositions, :is_active, :boolean, default: true
  end
end
