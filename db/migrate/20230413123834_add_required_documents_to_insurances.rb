class AddRequiredDocumentsToInsurances < ActiveRecord::Migration[6.0]
  def change
    add_column :insurances, :approved_date, :date
    add_column :insurances, :required_documents, :jsonb
    add_column :insurances, :info_data, :jsonb
  end
end
