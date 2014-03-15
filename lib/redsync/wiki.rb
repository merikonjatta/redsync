require 'uri'
require 'mechanize'
require 'yaml'

class Redsync
  class Wiki

    attr_reader :url,
                :api_key,
                :data_dir,
                :extension

    # Valid option values:
    #   :url => This wiki's base url. Required
    #   :cookies => Mechanize::Cookie objects that's already logged in to Redmine. Required
    #   :data_dir => Directory to read/write to. Required.
    #   :extension => File extensions for page files. Defaults to "txt"
    def initialize(options)
      @url = options[:url].match(/(.*?)\/?$/)[1]
      @api_key = options[:api_key]
      @data_dir = File.expand_path(options[:data_dir])
      @extension = options[:extension]

      @agent = Mechanize.new

      @pages_cache = {}
      @pages_cache_file = File.join(@data_dir, "__redsync_pages_cache.yml")

      initialize_system_files
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


    def downsync
      queue = pages_to_download
      queue.each_with_index do |page, i|
        puts "--Download (#{i+1} of #{queue.count}) #{page.name}"
        page.download
      end
      self.write_pages_cache
    end


    def upsync
      queue = pages_to_create
      queue.each_with_index do |page, i|
        puts "--Create (#{i+1} of #{queue.count}) #{page.name}"
        page.upload
      end
      self.write_pages_cache

      queue = pages_to_upload
      queue.each_with_index do |page, i|
        puts "--Upload (#{i+1} of #{queue.count}) #{page.name}"
        page.upload
      end
      self.write_pages_cache
    end


    def pages_to_download
      list = []
      list += @pages_cache.values.select { |page| page.exists_in == :remote_only }
      list += @pages_cache.values.select { |page| page.exists_in == :both && !page.synced_at }
      list += @pages_cache.values.select { |page| page.exists_in == :both && page.synced_at && (page.remote_updated_at > page.synced_at) }
      list
    end


    def pages_to_create
      list = []
      list += @pages_cache.values.select { |page| page.exists_in == :local_only }
      list
    end


    def pages_to_upload
      list = []
      list += @pages_cache.values.select { |page| page.exists_in == :both && (page.local_updated_at > page.synced_at) }
      list
    end


    def scan
      scan_remote
      scan_local
    end


    def scan_remote
      webpage = @agent.get(@url + "/date_index")

      # Get remote and local update times using remote list
      webpage.search("#content h3").each do |h3|
        links = h3.next_element.search("a")
        links.each do |link|
          url = URI.parse(@url).merge(link.attr("href")).to_s
          wiki_page = WikiPage.new(self, url)
          @pages_cache[wiki_page.name] = wiki_page unless @pages_cache[wiki_page.name]
          @pages_cache[wiki_page.name].remote_updated_at = h3.text
        end
      end
    end


    def scan_local
      Dir.entries(@data_dir).each do |file|
        next if File.directory? file
        next if file =~ /^__redsync_/
        page_name = file.match(/([^\/\\]+?)\.#{@extension}$/)[1]
        page_name = page_name.encode("UTF-8-MAC", "UTF-8", :invalid => :replace, :undef => :replace) if RUBY_PLATFORM =~ /darwin/
        next if pages[page_name]
        pp file
        wiki_page = WikiPage.new(self, page_name)
        pages[page_name] = wiki_page
      end
    end


    def write_pages_cache
      File.open(@pages_cache_file, "w+:UTF-8") do |f|
        f.write(self.pages.values.map{ |page| page.to_hash}.to_yaml)
      end
    end


    def load_pages_cache
      return unless File.exist? @pages_cache_file
      @pages_cache = {}
      YAML.load_file(@pages_cache_file).each do |page_hash|
        wiki_page = WikiPage.new(self, page_hash[:name])
        wiki_page.remote_updated_at = page_hash[:remote_updated_at]
        wiki_page.synced_at = page_hash[:synced_at]
        @pages_cache[page_hash[:name]] = wiki_page
      end
    end


    def to_s
      str = "#<Redsync::Wiki"
      str << " url = \"#{@url}\"\n"
      str << " data_dir = \"#{@data_dir}\"\n"
      str << " extension = \"#{@extension}\"\n"
      str << " pages = #{@pages_cache.count}\n"
      str << ">"
    end

  end
end
