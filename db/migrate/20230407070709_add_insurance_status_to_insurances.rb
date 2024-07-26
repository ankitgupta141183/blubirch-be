class AddInsuranceStatusToInsurances < ActiveRecord::Migration[6.0]
  def change
    add_column :insurances, :insurer_id, :integer
    add_column :insurances, :insurance_status, :integer
    add_column :insurances, :incident_date, :date
    add_column :insurances, :incident_location, :string
    add_column :insurances, :damage_type, :string
    add_column :insurances, :responsible_vendor, :string
    add_column :insurances, :claim_ticket_date, :date
    add_column :insurances, :claim_ticket_number, :string
    add_column :insurances, :inspection_report, :string
    add_column :insurances, :claim_decision, :integer
    add_column :insurances, :approval_ref_number, :string
    add_column :insurances, :estimated_loss, :float
    add_column :insurances, :benchmark_price, :float
    add_column :insurances, :net_recovery, :float
    add_column :insurances, :recovery_percent, :float
    add_column :insurances, :assigned_disposition, :string
    add_column :insurances, :incident_images, :json
    add_column :insurances, :incident_videos, :json
  end
end
