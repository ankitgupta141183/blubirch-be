class AddMasterDataInputIdColumnToExpArticles < ActiveRecord::Migration[6.0]
  def change
    add_column :exceptional_articles, :master_data_input_id, :integer
    add_column :exceptional_article_serial_numbers, :master_data_input_id, :integer
    add_column :exceptional_articles, :user_id, :integer
    add_column :exceptional_article_serial_numbers, :user_id, :integer
    remove_column :exceptional_articles, :serial_number_length
  end
end
