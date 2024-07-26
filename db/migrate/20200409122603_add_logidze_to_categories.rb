class AddLogidzeToCategories < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :categories, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_categories
      BEFORE UPDATE OR INSERT ON categories FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_categories on categories;"

    
    remove_column :categories, :log_data
    
    
  end
end
