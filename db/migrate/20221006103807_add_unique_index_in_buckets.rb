class AddUniqueIndexInBuckets < ActiveRecord::Migration[6.0]
  def change
    execute <<-SQL
      create unique index repairs_unique_row on repairs(tag_number) where is_active;
      create unique index replacements_unique_row on replacements(tag_number) where is_active;
      create unique index vendor_returns_unique_row on vendor_returns(tag_number) where is_active;
      create unique index liquidations_unique_row on liquidations(tag_number) where is_active;
      create unique index redeploys_unique_row on redeploys(tag_number) where is_active;  
      create unique index insurances_unique_row on insurances(tag_number) where is_active;
      create unique index markdowns_unique_row on markdowns(tag_number) where is_active;
      create unique index pending_dispositions_unique_row on pending_dispositions(tag_number) where is_active;
      create unique index e_wastes_unique_row on e_wastes(tag_number) where is_active; 
    SQL
  end
end