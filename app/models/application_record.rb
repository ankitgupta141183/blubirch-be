class ApplicationRecord < ActiveRecord::Base
  include Utils::Formatting
  extend Utils::Formatting
  
  self.abstract_class = true


end
