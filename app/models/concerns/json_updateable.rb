module JsonUpdateable

  include ActiveSupport::Concern

  def update_details(param)
    json_details = self.details.reject { |k,v| v.blank? }
    merged_hash = json_details.deep_merge(param.reject { |k,v| v.blank? })
    self.update(details: merged_hash)    
  end

  def merge_details(param)
    json_details = self.details.reject { |k,v| v.blank? }
    merged_hash = json_details.deep_merge(param.reject { |k,v| v.blank? })
    return merged_hash
  end

end