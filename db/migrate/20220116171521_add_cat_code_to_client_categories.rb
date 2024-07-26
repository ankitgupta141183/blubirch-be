class AddCatCodeToClientCategories < ActiveRecord::Migration[6.0]
  def change
    add_column :client_categories, :cat_code, :string
  end
end
