class AddLogidzeToLookupKeys < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :lookup_keys, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_lookup_keys
      BEFORE UPDATE OR INSERT ON lookup_keys FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_lookup_keys on lookup_keys;"

    
    remove_column :lookup_keys, :log_data
    
    
  end
end
