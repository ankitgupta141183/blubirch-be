class MasterFileUpload < ApplicationRecord
  acts_as_paranoid

  mount_uploader :master_file, FileUploader

  belongs_to :user
  belongs_to :client, optional: true
  belongs_to :distribution_center, optional: true

  validates :master_file_type, presence: true

  after_create :upload_file

  RETRY_STATUS = "Retrying"

	def upload_file
		# # sleep 60
		# GatePass.import_new(id)
		# self.update(status: "Import Started")
		MasterFileUploadWorker.perform_in(1.minutes, id)
	end

   def self.upload_pending_files
    MasterFileUpload.where(status: nil).where("date(created_at) = ?", Date.today).each do |inventory|
      MasterFileUploadWorker.new.perform(inventory.id)
    end
  end

  def retrying?
    RETRY_STATUS == status
  end
  
end
