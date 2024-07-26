class AddApproverIdToInsurances < ActiveRecord::Migration[6.0]
  def change
    add_column :insurances, :assigned_id, :integer
    add_column :insurances, :approver_id, :integer
  end
end
