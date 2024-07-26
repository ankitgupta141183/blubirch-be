class RemoveAccountSettingReferenceFromUser < ActiveRecord::Migration[6.0]
  def change
    remove_reference :account_settings, :user
  end
end
