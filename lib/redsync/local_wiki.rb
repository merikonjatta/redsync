class Redsync
  class LocalWiki

    def initialize(options)
      @data_dir = options[:data_dir]
      @extension = options[:extension]
    end


    def list
      unless @pages
        @pages = {}
        Dir["#{@data_dir}/**/*.#{@extension}"].each do |file|
          name = File.basename(file, "." + @extension)
          name = name.encode("UTF-8", "UTF-8-MAC", :invalid => :replace, :undef => :replace) if RUBY_PLATFORM =~ /darwin/
          @pages[name] = WikiPage.new(
            :name => name,
            :mtime => File.mtime(file)
          )
        end
      end

      @pages.values
    end


    def get(name)
      list unless @pages

      return nil if @pages[name].nil?

      unless @pages[name].content
        @pages[name].content = File.read(path_for(name))
      end

      @pages[name]
    end


    def write(name, content)
      File.open(path_for(name), "w+:UTF-8") do |f|
        f.write(content)
      end
    end


    def path_for(name)
      name = name.encode("UTF-8-MAC", "UTF-8", :invalid => :replace, :undef => :replace) if RUBY_PLATFORM =~ /darwin/
      File.join(@data_dir, name + "." + @extension)
    end

  end
end
