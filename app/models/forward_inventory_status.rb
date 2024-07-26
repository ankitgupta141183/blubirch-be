# frozen_string_literal: true

class ForwardInventoryStatus < ApplicationRecord
  acts_as_paranoid
  belongs_to :forward_inventory
  belongs_to :distribution_center
  belongs_to :user, optional: true
  belongs_to :status, class_name: 'LookupValue'
end
