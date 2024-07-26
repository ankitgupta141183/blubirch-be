class AccountSetting < ApplicationRecord
  enum benchmark_price: { mrp: 1 }
  enum bidding_method: { open: 1, hybrid: 2, blind: 3 }, _prefix: true

  # Params -> ["amazon", "flipcart"]
  # AccountSetting.first.update_ext_b2c_platforms(["bmaxx","amazon"])
  def update_ext_b2c_platforms(arr_data)
    json_data = {}
    arr_data.each do |data|
      json_data[data.to_s.downcase] = data.humanize
    end
    self.update!(ext_b2c_platforms: json_data) if json_data.present?
  end
end
