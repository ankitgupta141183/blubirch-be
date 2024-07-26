class AddStatusColumnIntoRepairHistory < ActiveRecord::Migration[6.0]
  def change
  	add_column :repair_histories, :status, :string
  end
end
