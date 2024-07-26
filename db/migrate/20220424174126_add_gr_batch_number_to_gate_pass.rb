class AddGrBatchNumberToGatePass < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :gr_batch_number, :string
    add_column :gate_pass_inventories, :imei_flag, :string, default: "0"
  end
end
