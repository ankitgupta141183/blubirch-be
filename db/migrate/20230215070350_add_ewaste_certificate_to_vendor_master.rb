class AddEwasteCertificateToVendorMaster < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_masters, :e_waste_certificate, :string
  end
end
