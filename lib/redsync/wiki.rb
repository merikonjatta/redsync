require 'uri'
require 'mechanize'
require 'datetime_nil_compare'

class Redsync
  class Wiki

    attr_reader :url,
                :data_dir,
                :extension

    # Valid option values:
    #   :url => This wiki's base url. Required
    #   :cookies => Mechanize::Cookie objects that's already logged in to Redmine. Required
    #   :data_dir => Directory to read/write to. Required.
    #   :extension => File extensions for page files. Defaults to "txt"
    def initialize(options)
      @url = options[:url].match(/(.*?)\/?$/)[1]
      @data_dir = File.expand_path(options[:data_dir])
      @extension = options[:extension]

      @agent = Mechanize.new
      options[:cookies].each do |cookie|
        @agent.cookie_jar.add(URI.parse(@url), cookie)
      end

      @pages_cache = {}

      initialize_system_files
    end


    def cookies
      @agent.cookie_jar.cookies(URI.parse(@url))
    end

    def initialize_system_files
      unless File.exist? @data_dir
        puts "Creating #{@data_dir}"
        FileUtils.mkdir(@data_dir) 
      end
    end


    def pages
      @pages_cache
    end


    def remote_updated_pages
      @pages_cache.inject([]) do |sum, (name, page)|
        sum << name if page.remote_updated_at > page.local_updated_at
        sum
      end
    end


    def scan_remote
      webpage = @agent.get(@url + "/date_index")
      now = DateTime.now

      # Get remote and local update times using remote list
      webpage.search("#content h3").each do |h3|
        links = h3.next_element.search("a")
        links.each do |link|
          url = URI.parse(@url).merge(link.attr("href")).to_s
          wiki_page = WikiPage.new(self, url)
          wiki_page.remote_updated_at = h3.text
          @pages_cache[wiki_page.name] = wiki_page
        end
      end
    end

  end
end
