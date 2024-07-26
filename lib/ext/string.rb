class String
  #& split_with_gsub
  def split_with_gsub
    self.to_s.gsub(" ", "").split(',')
  end
end