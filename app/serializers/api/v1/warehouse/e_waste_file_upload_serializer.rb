class Api::V1::Warehouse::EWasteFileUploadSerializer < ActiveModel::Serializer

	attributes :id, :e_waste_file, :filename, :status , :remarks, :created_at , :updated_at 

	belongs_to :user
	belongs_to :client, optional: true

	def filename 
		object.e_waste_file.file.original_filename rescue nil
	end

	def user_name
   	object.user.username rescue nil
  end
	
end