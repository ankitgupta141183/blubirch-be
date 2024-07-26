class UpdateThirdPartyClaimData < ActiveRecord::Migration[6.0]
  def change
    ThirdPartyClaim.where(status: :closed).update_all(tab_status: :closed)
    ThirdPartyClaim.where(stage_name: :repair_cost).update_all(tab_status: :cost)
    ThirdPartyClaim.where.not(stage_name: :repair_cost).update_all(tab_status: :recovery)
  end
end
