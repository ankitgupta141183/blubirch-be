module GenerateTagNumber
  extend ActiveSupport::Concern

  def generate_uniq_tag_number(old_uniq_id = nil)
    chars = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
    random_string = Array.new(4) { chars.sample }.join('')
    random_numbers = SecureRandom.random_number(999)
    random_string + random_numbers.to_s 
  end

  
  def validate_uniqueness(validate_with_array, compareable_array, generated_number, class_name = nil, key_name = nil)
    return false if generated_number.blank?
    if validate_with_array.present? && compareable_array.present?
      compareable_array.exclude?(generated_number)
    else
      class_name.constantize.unscoped.where(key_name.to_sym => generated_number).empty?
    end
  end
end
