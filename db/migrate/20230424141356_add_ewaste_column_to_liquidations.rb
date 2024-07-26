class AddEwasteColumnToLiquidations < ActiveRecord::Migration[6.0]
  def change
    # Added string because here default value is not false. Its empty. 
    add_column :liquidations, :is_ewaste, :string, default: ''
  end
end
