class AddDatesToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :receipt_date, :datetime
    add_column :items, :dispatch_date, :datetime
    add_column :items, :current_status, :string
    add_column :items, :pod, :string
  end
end
