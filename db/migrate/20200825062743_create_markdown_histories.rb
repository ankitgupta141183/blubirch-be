class CreateMarkdownHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :markdown_histories do |t|
      t.integer :markdown_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :markdown_histories, :markdown_id
  end
end
