class Redsync
  class WikiPage
    attr_accessor :name, :mtime, :content
    
    def initialize(options)
      @name = options[:name]
      @mtime = options[:mtime]
      @content = options[:content]
    end
  end
end
