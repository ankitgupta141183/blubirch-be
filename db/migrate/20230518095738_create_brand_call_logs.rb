class CreateBrandCallLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :brand_call_logs do |t|
      t.integer  :distribution_center_id
      t.integer  :inventory_id
      t.integer  :client_sku_master_id
      t.string   :tag_number
      t.string   :call_log_id
      t.string   :sku_code
      t.string   :item_description
      t.boolean  :is_active, default: true
      t.string   :brand
      t.string   :grade
      t.string   :vendor
      t.string   :supplier
      t.integer  :status
      t.string   :order_number
      t.jsonb    :details
      t.string   :sr_number
      t.string   :serial_number
      t.string   :serial_number2
      t.string   :toat_number
      t.string   :ticket_number
      t.date     :ticket_date
      t.date     :inspection_date
      t.string   :inspection_report
      t.text     :inspection_remarks
      t.string   :approval_ref_number
      t.date     :approved_date
      t.string   :brand_decision
      t.string   :credit_note_number
      t.float    :item_price
      t.float    :benchmark_price
      t.float    :net_recovery
      t.float    :recovery_percent
      t.string   :assigned_disposition
      t.jsonb    :required_documents
      t.integer  :assigner_id
      t.integer  :approver_id
      t.string   :client_tag_number

      t.timestamps
    end
  end
end
