class AddColumnForPendingRepairRgp < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :pending_repair_rgp_number, :string
    add_column :repairs, :pending_repair_location, :string
  end
end
