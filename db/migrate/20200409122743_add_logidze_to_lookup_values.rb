class AddLogidzeToLookupValues < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :lookup_values, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_lookup_values
      BEFORE UPDATE OR INSERT ON lookup_values FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_lookup_values on lookup_values;"

    
    remove_column :lookup_values, :log_data
    
    
  end
end
