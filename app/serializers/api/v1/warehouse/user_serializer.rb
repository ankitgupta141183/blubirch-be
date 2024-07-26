class Api::V1::Warehouse::UserSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :email, :role, :contact_no, :status, :employee_id, :username, :product_access, :module_access, :onboarded_by, :role_name

  def module_access
    result = []
    object.distribution_center_users.each do |data|
      data.details.each do |detail|
        if detail["disposition"] == "All"
          result << detail
          return result
        else  
          result << detail
        end
      end
    end
    return result
  end

  def status
    object.deleted_at.present? ? "Inactive" : "Active"
  end

  def product_access
    object.tasks["product_access"] rescue ''
  end

  def role
    object.roles.last.id rescue ''
  end

  def role_name
    if object.roles.present?
      object.roles.last.code
    else
      ""
    end
  end

  def onboarded_by
    object.try(:onboarded_user)
  end

end
