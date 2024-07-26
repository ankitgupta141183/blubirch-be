class AddColumnToRtvAttachment < ActiveRecord::Migration[6.0]
  def change
    add_column :rtv_attachments, :deleted_at, :datetime
  end
end
