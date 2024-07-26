class AddLogidzeToAttributeMasters < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :attribute_masters, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_attribute_masters
      BEFORE UPDATE OR INSERT ON attribute_masters FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_attribute_masters on attribute_masters;"

    
    remove_column :attribute_masters, :log_data
    
    
  end
end
