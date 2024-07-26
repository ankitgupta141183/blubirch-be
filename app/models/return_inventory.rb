class ReturnInventory < ApplicationRecord

  belongs_to :inventory
  
  #^ ReturnInventory.question_map_to_side
  def self.question_map_to_side(question)
    hash = {
      "Capture photo of front side of the item" => "front",
      "Capture photo of back side of the item" => "back",
      "Capture photo of logo of the item" => nil,
      "Does item have side pocket logo?" => nil,
      "Is stitching clean and consistent?" => nil
    }
    return hash[question]
  end

end
