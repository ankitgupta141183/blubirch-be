class AddClientCategoryIdToRedeploy < ActiveRecord::Migration[6.0]
  def change
    add_column :redeploys, :client_category_id, :integer
  end
end
