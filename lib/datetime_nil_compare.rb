require 'date'

class << nil
  def to_datetime
    DateTime.civil
  end
end
