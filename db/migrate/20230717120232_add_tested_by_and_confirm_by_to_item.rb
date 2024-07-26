class AddTestedByAndConfirmByToItem < ActiveRecord::Migration[6.0]
  def change
    add_column :items, :tested_by, :string
    add_column :items, :confirmed_by, :string
  end
end
