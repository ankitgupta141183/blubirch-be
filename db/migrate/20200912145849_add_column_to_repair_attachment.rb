class AddColumnToRepairAttachment < ActiveRecord::Migration[6.0]
  def change
    add_column :repair_attachments, :deleted_at, :datetime
  end
end
