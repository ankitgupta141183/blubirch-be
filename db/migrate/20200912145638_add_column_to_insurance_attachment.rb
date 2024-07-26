class AddColumnToInsuranceAttachment < ActiveRecord::Migration[6.0]
  def change
    add_column :insurance_attachments, :deleted_at, :datetime
  end
end
