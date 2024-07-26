class RenameColumnIntoRepairTable < ActiveRecord::Migration[6.0]
  def change
  	rename_column :repairs, :authorizatio_user_id , :authorization_user_id
  end
end
