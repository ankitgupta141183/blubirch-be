class Error < ApplicationRecord
  validates :timestamp, :error_type, :error_message, presence: true

  def formatted_timestamp
    timestamp.strftime('%Y-%m-%d %H:%M:%S %Z') if timestamp.present?
  end
end
