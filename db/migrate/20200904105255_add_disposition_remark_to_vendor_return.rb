class AddDispositionRemarkToVendorReturn < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :disposition_remark, :text
    add_column :rtv_attachments, :attachment_file_type_id, :integer
  end
end
