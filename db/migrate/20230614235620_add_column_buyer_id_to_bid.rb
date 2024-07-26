class AddColumnBuyerIdToBid < ActiveRecord::Migration[6.0]
  def change
    add_column :bids, :buyer_id, :string
    add_column :bids, :beam_bid_id, :string
    add_column :bids, :shipping_addr1, :string
    add_column :bids, :shipping_addr2, :string
    add_column :bids, :shipping_addr3, :string
    add_column :bids, :shipping_city, :string
    add_column :bids, :shipping_state, :string
    add_column :bids, :shipping_country, :string
    add_column :bids, :shipping_pincode, :string
  end
end
