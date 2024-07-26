class AddFieldsToConsignments < ActiveRecord::Migration[6.0]
  def change
    add_column :consignments, :consignment_id, :string
    add_column :consignments, :distribution_center_id, :integer
    add_column :consignments, :status, :integer
    add_column :consignments, :consignment_receipt, :string
    add_column :consignments, :acknowledgement_receipt, :string
    add_column :consignments, :damage_certificates, :json
    
    remove_column :consignment_informations, :consignment_id
    add_column :consignment_informations, :consignment_id, :integer
    
    add_column :consignment_box_images, :consignment_id, :integer
  end
end
