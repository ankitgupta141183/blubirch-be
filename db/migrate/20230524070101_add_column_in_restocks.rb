class AddColumnInRestocks < ActiveRecord::Migration[6.0]
  def change
    add_column :restocks, :category, :string
  end
end
