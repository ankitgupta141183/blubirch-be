# frozen_string_literal: true

# nodoc
module AssociatedRecordsUpdateable
  extend ActiveSupport::Concern

  def update_all_associated_destribution_id(distribution_center_id)
    # Get all the associations of the Inventory model
    associations = self.class.reflect_on_all_associations

    # Iterate through the associations and update the distribution_center_id
    associations.each do |association|
      next unless association.macro == :has_many || association.macro == :has_one

      associated_model = association.class_name.constantize
      next unless associated_model.column_names.include?('distribution_center_id')

      # as PutRequest is assocation with Through, so we dont need to update
      next if [PutRequest].include?(associated_model)
      associated_records = associated_model.where(inventory_id: id)
      associated_records.each do |associated_rec|
        associated_rec.update(distribution_center_id: distribution_center_id)
      end
    end
  end
end
