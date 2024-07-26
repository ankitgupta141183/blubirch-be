class AddSiteCategoryToDistributionCenters < ActiveRecord::Migration[6.0]
  def change
    add_column :distribution_centers , :site_category, :string
  end
end
