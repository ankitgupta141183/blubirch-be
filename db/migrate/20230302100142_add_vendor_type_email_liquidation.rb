class AddVendorTypeEmailLiquidation < ActiveRecord::Migration[6.0]
  def change
    reversible do |migration|
      migration.up do
        execute <<-SQL
          UPDATE Lookup_values SET original_code = 'Email Liquidation', code = 'vendor_type_email_liquidation'
          WHERE code = 'vendor_type_liquidation';

          INSERT INTO vendor_types (vendor_master_id, vendor_type_id, vendor_type)
          SELECT id, CASE WHEN vendor_type_id IS NULL THEN (SELECT id FROM Lookup_values WHERE code = 'vendor_type_email_liquidation') ELSE vendor_type_id END AS vendor_type_id,
          CASE WHEN vendor_type = 'Liquidation' THEN 'Email Liquidation' ELSE vendor_type END AS vendor_type from vendor_masters;
        SQL

        remove_column :vendor_masters, :vendor_type_id
        remove_column :vendor_masters, :vendor_type
      end

      migration.down do
        add_column :vendor_masters, :vendor_type_id, :integer
        add_column :vendor_masters, :vendor_type,    :string

        execute <<-SQL
          UPDATE Lookup_values SET original_code = 'Liquidation', code = 'vendor_type_liquidation'
          WHERE code = 'vendor_type_email_liquidation';

          UPDATE vendor_masters SET vendor_type_id = vendor_types.vendor_type_id,
          vendor_type = CASE WHEN vendor_types.vendor_type = 'Email Liquidation' THEN 'Liquidation' ELSE vendor_types.vendor_type END
          FROM vendor_types WHERE vendor_masters.id = vendor_types.vendor_master_id;

          TRUNCATE vendor_types;
        SQL
      end
    end
  end
end
