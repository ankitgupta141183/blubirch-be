class AddColumnToReplacementAttachment < ActiveRecord::Migration[6.0]
  def change
    add_column :replacement_attachments, :deleted_at, :datetime
  end
end
