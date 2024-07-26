module SkuCodeQuery
  extend ActiveSupport::Concern

  def build_sku_code_query(sku_code)
    "LOWER(changed_sku_code) = '#{sku_code}' OR LOWER(sku_code) = '#{sku_code}'"
  end
end
