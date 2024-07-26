class AddLogidzeToClients < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :clients, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_clients
      BEFORE UPDATE OR INSERT ON clients FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_clients on clients;"

    
    remove_column :clients, :log_data
    
    
  end
end
