class DealerSerializer < ActiveModel::Serializer

	attributes :id, :dealer_code, :company_name, :first_name, :last_name, :email, :phone_number, :dealer_type_id, :dealer_type, :gst_number, :pan_number, :cin_number, :account_number, :bank_name, :ifsc_code, :address_1, :address_2, :city_id, :city, :state_id, :state, :country_id, :country, :pincode, :status_id, :status, :ancestry, :onboarded_user_id, :onboarder_by, :onboarded_employee_code, :onboarded_employee_phone_no, :deleted_at, :created_at, :updated_at

end