class User < ApplicationRecord

  include Devise::JWT::RevocationStrategies::JTIMatcher
  include Filterable
  include UserSearchable

  validates_format_of :email,:with => Devise::email_regexp
  validates :username, :first_name, :last_name,  presence: true
  validates :username, uniqueness: true
  # validates :contact_no, :presence => true, :numericality => true, :length => { :minimum => 10}


  scope :filter_by_username, -> (username) { where("username ilike ?", "%#{username}%")}
  scope :filter_by_first_name, -> (firstname) { where("first_name ilike ?", "%#{firstname}%")}
  scope :filter_by_last_name, -> (lastname) { where("last_name ilike ?", "%#{lastname}%")}
  scope :filter_by_contact_no, -> (contact_no) { where("contact_no ilike ?", "%#{contact_no}%")}
  scope :filter_by_email, -> (email) { where("email ilike ?", "%#{email}%")}

  attr_writer :login

  def login
    @login || self.username || self.email
  end

  has_logidze
  acts_as_paranoid
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: self, authentication_keys: [:login]

  has_many :user_roles , dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :report_statuses

  has_many :distribution_center_users , dependent: :destroy
  has_many :distribution_centers, through: :distribution_center_users

  has_many :dealer_users , dependent: :destroy
  has_many :dealers, through: :dealer_users


  has_many :master_file_uploads
  has_many :packaging_boxes
  has_many :gate_passes
  has_many :consignments
  has_many :items
  has_many :consignment_details
  # has_many :put_requests, class_name: "PutRequest", foreign_key: :assignee_id
  has_many :user_requests
  has_many :put_requests, through: :user_requests
  has_many :approval_requests
  has_many :ecom_liquidations
  has_many :payment_histories

  belongs_to :onboarded_user , class_name: "User", foreign_key: "onboarded_by"

  has_one :user_account_setting

  def user_account_setting
    super || build_user_account_setting
  end

  def bidding_method
    user_account_setting&.bidding_method.presence || AccountSetting.first.bidding_method rescue 'N/A'
  end

  def organization_name
    user_account_setting&.organization_name.presence || AccountSetting.first.organization_name rescue 'N/A'
  end

  def distribution_center_ids
    self.distribution_centers.pluck(:id)
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    elsif conditions.has_key?(:username) || conditions.has_key?(:email)
      where(conditions.to_h).first
    end
  end

  def full_name
    "#{first_name} #{last_name}".split.map(&:capitalize).join(' ')
  end

  def jwt_payload
	  super.merge({ "user_id" => self.id, roles: self.roles.collect(&:code) })
	end

  def generate_password_token!
    self.reset_password_token = generate_token
    self.reset_password_sent_at = Time.now.utc
    save!
  end

  def password_token_valid?
    (self.reset_password_sent_at + 3.hours) > Time.now.utc
  end

  def reset_password!(password)
    self.reset_password_token = nil
    self.password = password
    save!
  end

  private

  def generate_token
    SecureRandom.hex(10)
  end

end
