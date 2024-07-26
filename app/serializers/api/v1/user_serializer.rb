class Api::V1::UserSerializer < ActiveModel::Serializer

  attributes :id, :username, :email, :first_name, :last_name, :contact_no, :deleted_at, :roles, :status, :sign_in_count, :product_access, :accessible_dispositions, :distribution_center_ids, :available_distribution_centers

  def roles
    object.roles.collect(&:code).uniq
  end

  def accessible_dispositions
    result = []
    object.distribution_center_users.each do |distribution_center_user|
      distribution_center_user.details.each do |details|
        result << details["disposition"]
      end
    end
    if ["Site Admin", "Central Admin"].include?(object.roles.last.name)
      result << "All"
    end
    return result.uniq
  end

  def product_access
    object.tasks["product_access"] rescue []
  end

  def status
    object.deleted_at.present? ? "Inactive" : "Active"
  end

  def distribution_center_ids
    object.distribution_centers.pluck(:code)
  end

  def available_distribution_centers
     if object.distribution_centers.size > 1
      object.distribution_centers.map{ |dc| {code: dc.code, id: dc.id}}.unshift({code: "ALL RPA", id:0})
    else
      object.distribution_centers.map{ |dc| {code: dc.code, id: dc.id}}
    end
  end

end