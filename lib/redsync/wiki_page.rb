require 'fileutils'
require 'date'
require 'active_support/all'
require 'redsync/wiki'

class Redsync
  class WikiPage
    attr_reader   :name,
                  :local_file,
                  :url,
                  :local_updated_at
    attr_accessor :remote_updated_at,
                  :downloaded_at


    def initialize(wiki, name_or_url_or_fullpath)
      @wiki = wiki

      if name_or_url_or_fullpath =~ /^#{@wiki.data_dir}\/(.*)$/
        @local_file = name_or_url_or_fullpath
        @name = $1
        @url = @wiki.url + "/" + @name
      elsif name_or_url_or_fullpath =~ /^#{@wiki.url}\/(.*)$/
        @url = name_or_url_or_fullpath
        @name = URI.decode($1)
        @local_file = File.join(@wiki.data_dir, "#{@name}.#{@wiki.extension}")
      else
        @name = name_or_url_or_fullpath
        @local_file = File.join(@wiki.data_dir, "#{@name}.#{@wiki.extension}")
        @url = @wiki.url + "/" + @name
      end

      @agent = Mechanize.new
      @wiki.cookies.each do |cookie|
        @agent.cookie_jar.add(URI.parse(@url), cookie)
      end
    end


    def local_exists?
      File.exist? @local_file
    end


    def local_updated_at
      if local_exists?
        File.stat(@local_file).mtime.to_datetime
      else
        nil
      end
    end


    def remote_exists?
      !remote_updated_at.nil?
    end


    def remote_updated_at
      at = @remote_updated_at
      now = DateTime.now
      if at && ([at.year, at.month, at.day] == [now.year, now.month, now.day])
        return @remote_updated_at = history[0][:timestamp]
      else
        return at
      end
    end


    def remote_updated_at=(value)
      @remote_updated_at = DateTime.parse(value.to_s) if value
    end


    def downloaded_at
      @downloaded_at
    end


    def downloaded_at=(value)
      @downloaded_at = DateTime.parse(value.to_s) if value
    end


    def history
      puts "--Getting page history for #{name}" if @config[:verbose]
      now = DateTime.now
      history = []
      page = @agent.get(@config[:wiki_base_url] + "/" + URI.encode(name) + "/history")
      page.search("table.wiki-page-versions tbody tr").each do |tr|
        timestamp = DateTime.parse(tr.search("td")[3].text + now.zone) 
        author_name = tr.search("td")[4].text.strip
        history << {
          :timestamp => timestamp,
          :author_name => author_name
        }
      end
      history
    end


    def download
      puts "--Download #{@name}"
      page = @agent.get(@url + "/edit")
      File.open(@local_file, "w+:UTF-8") { |f| f.write(page.search("textarea")[0].text) }
      self.downloaded_at = self.local_updated_at
    end


    def to_s
      str = "#<WikiPage"
      str << " name = \"#{name}\"\n"
      str << " local_file = \"#{local_file}\"\n"
      str << " url = \"#{url}\"\n"
      str << " remote_exists? = #{remote_exists?}\n"
      str << " remote_updated_at = #{@remote_updated_at ? @remote_updated_at : "<never>"}\n"
      str << " local_exists? = #{local_exists?}\n"
      str << " local_updated_at = #{local_updated_at ? local_updated_at : "<never>"}\n"
      str << " downloaded_at = #{@downloaded_at ? @downloaded_at : "<never>"}\n"
      str << ">"
    end

    
  end
end
