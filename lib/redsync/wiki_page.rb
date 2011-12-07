require 'fileutils'
require 'date'
require 'active_support/all'
require 'redsync/wiki'

class Redsync
  class WikiPage
    attr_accessor :name,
                  :local_file,
                  :url,
                  :remote_updated_at,
                  :downloaded_at


    def initialize(wiki, name_or_url_or_fullpath)
      @config = redsync.config
      @syncstat = redsync.syncstat
      @agent = redsync.agent

      if name_or_url_or_fullpath =~ /^#{@config[:data_dir]}\/(.*)$/
        @local_file = name_or_url_or_fullpath
        @name = $1
        @url = @config[:wiki_base_url] + "/" + @name
      elsif name_or_url_or_fullpath =~ /^#{@config[:wiki_base_url]}\/(.*)$/
        @url = name_or_url_or_fullpath
        @name = $1
        @local_file = File.join(@config[:data_dir], "#{@name}.#{@config[:extension]}")
      else
        @name = name_or_url_or_fullpath
        @local_file = File.join(@config[:data_dir], "#{@name}.#{@config[:extension]}")
        @url = @config[:wiki_base_url] + "/" + @name
      end
    end


    def local_exists?
      File.exist? @local_file
    end


    def local_updated_at
      if local_exists?
        File.stat(@local_file).mtime.to_datetime
      else
        DateTime.civil
      end
    end


    def remote_exists?
      !remote_updated_at.nil?
    end


    def remote_updated_at
      now = DateTime.now
      at = @syncstat.for(name)[:remote_updated_at]
      if at.year == now.year && at.month == now.month && at.day == now.day
        at = history[0][:timestamp]
      end
      at
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


    def to_s
      str = "#<WikiPage"
      str << " name = \"#{name}\"\n"
      str << " local_file = \"#{local_file}\"\n"
      str << " local_exists? = #{local_exists?}\n"
      str << " local_updated_at = #{local_updated_at}\n"
      str << " url = \"#{url}\"\n"
      str << " remote_updated_at = #{remote_updated_at}\n"
      str << " remote_exists? = #{remote_exists?}\n"
      str << " downloaded_at = #{downloaded_at}\n"
      str << ">"
    end

    
  end
end
