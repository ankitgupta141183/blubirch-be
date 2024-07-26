class RedeployHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :redeploy
end
