class ClientToken < ApplicationRecord
  def update_last_used
    update_column(:last_used_at, Time.current)
  end
end
