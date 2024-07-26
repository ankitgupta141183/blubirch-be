class AddApprovalFieldsToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :settlement_method, :string
    add_column :return_items, :settlement_method_id, :integer
    add_column :return_items, :item_decision, :integer
    add_column :return_items, :refund_amount, :float
    add_column :return_items, :repair_location, :integer
    add_column :return_items, :movement_mode, :integer
    add_column :return_items, :discount_amount, :float
    add_column :return_items, :remarks, :text
    add_column :return_items, :internal_recovery_method, :integer
    add_column :return_items, :vendor_code, :string
    add_column :return_items, :vendor_name, :string
    add_column :return_items, :apply_revised_exchange_value, :boolean
    add_column :return_items, :revised_amount, :float
    add_column :return_items, :spare_details, :jsonb
    add_column :return_items, :lease_deduction_amount, :float
    add_column :return_items, :approved_at, :datetime
    add_column :return_items, :approved_by, :integer
    
    add_index :return_items, :settlement_method
    add_index :return_items, :settlement_method_id
    add_index :return_items, :item_decision
    add_index :return_items, :repair_location
    add_index :return_items, :movement_mode
  end
end
