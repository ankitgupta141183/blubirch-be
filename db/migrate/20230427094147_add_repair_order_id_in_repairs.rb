class AddRepairOrderIdInRepairs < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :repair_order_id, :integer
  end
end
