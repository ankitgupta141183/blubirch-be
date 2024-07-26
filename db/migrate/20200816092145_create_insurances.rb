class CreateInsurances < ActiveRecord::Migration[6.0]
  def change
    create_table :insurances do |t|

      t.integer :distribution_center_id
      t.integer :inventory_id
      t.string :tag_number
      t.string :sku_code
      t.text :item_description
      t.string :sr_number
      t.string :aisle_location
      t.string :brand
      t.string :grade
      t.string :vendor
      t.jsonb :details
      t.string :call_log_id
      t.integer :status_id
      t.string :status
      t.datetime :claim_submission_date
      t.float :claim_amount
      t.text :claim_submission_remarks
      t.datetime :claim_inspection_date
      t.text :claim_inspection_remarks
      t.float :approved_amount
      t.text :action_remarks
      t.text :disposition_remark
      t.integer :insurance_order_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :insurances, :inventory_id
    add_index :insurances, :distribution_center_id
    add_index :insurances, :status_id
    add_index :insurances, :insurance_order_id
  end
end
