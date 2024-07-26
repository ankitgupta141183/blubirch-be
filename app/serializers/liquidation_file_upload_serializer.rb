class LiquidationFileUploadSerializer < ActiveModel::Serializer

	attributes :id, :liquidation_file, :filename, :status , :remarks, :created_at , :updated_at 

	belongs_to :user
	belongs_to :client, optional: true


	def filename 
		object.liquidation_file.file.original_filename rescue nil
	end

	def user_name
   	object.user.username rescue nil
  end
	
end
