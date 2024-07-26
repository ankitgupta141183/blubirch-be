class AddReapirFieldsIntoRepair < ActiveRecord::Migration[6.0]
  def change
  	add_column :repairs, :email_date, :datetime
    add_column :repairs, :rgp_number, :string
	add_column :repairs, :repair_date, :datetime
	add_column :repairs, :repair_amount, :float
	add_column :repairs, :repair_location_id, :integer
	add_column :repairs, :repair_location, :string
	add_column :repairs, :status, :string
	add_column :repairs, :authorized_by, :string
	add_column :repairs, :authorizatio_user_id, :integer
  end
end