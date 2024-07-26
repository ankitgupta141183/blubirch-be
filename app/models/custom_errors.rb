class CustomErrors < StandardError
  attr_accessor :message, :code, :data

  def initialize(message, code = -1, data = {})
    @message = message
    @code = code
    @data = data
    super(message)
  end
end