class AddClientCategoryIdToMarkdown < ActiveRecord::Migration[6.0]
  def change
    add_column :markdowns, :client_category_id, :integer
  end
end
