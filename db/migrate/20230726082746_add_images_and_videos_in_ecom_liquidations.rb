class AddImagesAndVideosInEcomLiquidations < ActiveRecord::Migration[6.0]
  def change
    add_column :ecom_liquidations, :ecom_images, :json
    add_column :ecom_liquidations, :ecom_videos, :json
  end
end
