class Api::V1::Warehouse::UserListSerilaizer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :email, :contact_no, :status, :employee_id, :username, :onboarded_by, :role_name

  def status
    object.deleted_at.present? ? "Inactive" : "Active"
  end

  def role_name
    if object.roles.present?
      object.roles.last.code
    else
      ""
    end
  end

end
