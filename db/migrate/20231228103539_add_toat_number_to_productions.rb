class AddToatNumberToProductions < ActiveRecord::Migration[6.0]
  def change
    add_column :productions, :production_status, :integer
    add_column :productions, :toat_number, :string
  end
end
