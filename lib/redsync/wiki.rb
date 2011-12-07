
class Redsync
  class Wiki

    attr_reader :base_url,
                :agent
    
    def initialize(redsync)
      @config = redsync.config
      @agent = redsync.agent
      @base_url = @config[:url] + "projects/" + @config[:project_slug] + "/wiki"
      @pages = {}
    end

    def scan_remote
      webpage = @agent.get(@base_url + "/date_index")
      now = DateTime.now

      # Get remote and local update times using remote list
      webpage.search("#content h3").each do |h3|
        links = h3.next_element.search("a")
        links.each do |link|
          url = @config[:url] + link.attr("href")
          wiki_page = WikiPage.new(self, url)

          update(name, {
            :name => name,
            :url => url,
            :local_file => local_file,
            :remote_updated_at => remote_updated_at,
            :local_updated_at => local_updated_at,
          }, true)

          update(name, {
            :downloaded_at => local_updated_at
          }, true) unless File.exist? local_file
        end
    end

  end
end
