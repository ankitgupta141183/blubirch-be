class AddLogidzeToDistributionCenters < ActiveRecord::Migration[5.0]
  require 'logidze/migration'
  include Logidze::Migration

  def up
    
    add_column :distribution_centers, :log_data, :jsonb
    

    execute <<-SQL
      CREATE TRIGGER logidze_on_distribution_centers
      BEFORE UPDATE OR INSERT ON distribution_centers FOR EACH ROW
      WHEN (coalesce(#{current_setting('logidze.disabled')}, '') <> 'on')
      EXECUTE PROCEDURE logidze_logger(null, 'updated_at');
    SQL

    
  end

  def down
    
    execute "DROP TRIGGER IF EXISTS logidze_on_distribution_centers on distribution_centers;"

    
    remove_column :distribution_centers, :log_data
    
    
  end
end
