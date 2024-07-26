class EcomLiquidation < ApplicationRecord

  has_many :ecom_purchase_histories
  belongs_to :user
  belongs_to :inventory
  belongs_to :liquidation
  has_one :warehouse_order, as: :orderable
  after_create :create_record_on_platform

  mount_uploaders :ecom_images, ConsignmentFileUploader
  mount_uploaders :ecom_videos, ConsignmentFileUploader

  enum status: { 'Pending B2C Publish': 'Pending B2C Publish', 'In Progress B2C': 'In Progress B2C', 'B2C Pending Decision': 'B2C Pending Decision', 'Dispatch': 'Dispatch' }
  enum publish_status: { publish_approval: 1, published: 2, publish_initiated: 3, failed: 4 }, _prefix: true
  enum platform: { 'bmaxx': 'bmaxx' }, _prefix: true

  validates_presence_of :platform, :amount, :quantity, :tag_number
  validates_uniqueness_of :tag_number


  #! EcomLiquidation.send_request_ext_platform(post, http://bmaxx.com, {data:})
  def self.send_request_ext_platform(method, url, payload)
    RestClient::Request.execute(method: method, url: url, payload: payload, headers: { "Authorization" => StringEncryptDecryptService.encrypt_string(Rails.application.credentials.b2c_publish_key) }, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
  end

  # EcomLiquidation.update_expired_ecom_liquidation
  def self.update_expired_ecom_liquidation
    status = LookupValue.where(original_code: 'B2C Pending Decision').first
    EcomLiquidation.where(status: 'In Progress B2C').each do |ecom_liquidation|
      if DateTime.now > ecom_liquidation.end_time.to_datetime
        ecom_liquidation.update!(status: 'B2C Pending Decision')
        ecom_liquidation.liquidation.update!(status: status.original_code, status_id: status.id)
      end
    end
  end

  def create_record_on_platform
    PublishEcomLiquidationWorker.perform_async([self.id])
  end

  #EcomLiquidation.resync_ecom_liquidation_records
  def self.resync_ecom_liquidation_records
    ecom_liq_records = self.where(publish_status: [:publish_initiated, :failed])
    ecom_liq_records.each do |ecom_liq|
      ecom_liq.create_record_on_platform
    end
  end
end
