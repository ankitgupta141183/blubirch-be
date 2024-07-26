class AddRejectedAtToReturnItems < ActiveRecord::Migration[6.0]
  def change
    add_column :return_items, :rejected_at, :datetime
    add_column :return_items, :rejected_by, :integer
  end
end
