class AddAssignedDispositionColumnInRepairs < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :assigned_disposition, :string
    add_column :repairs, :assigned_id, :integer
  end
end
