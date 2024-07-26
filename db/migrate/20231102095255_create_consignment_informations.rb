class CreateConsignmentInformations < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_informations do |t|
      t.references :distribution_center
      t.references :logistics_partner
      t.string :consignment_id
      t.string :dispatch_document_number
      t.string :consignee_ref_document_number
      t.string :irrd_number
      t.string :vendor_ref_number
      t.integer :status
      t.integer :boxes_count
      t.integer :good_boxes_count
      t.integer :damaged_boxes_count
      t.integer :user_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
