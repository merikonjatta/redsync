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
        @url = @wiki.url + "/" + URI.encode(@name)
      end

      @agent = Mechanize.new
      @wiki.cookies.each do |cookie|
        @agent.cookie_jar.add(URI.parse(@url), cookie)
      end
    end


    # Returns one of :remote_only, :local_only, :both or :nowhere
    # (:nowhere should never happen...)
    def exists_in
      if self.local_exists? && self.remote_exists?
        return :both
      elsif self.local_exists?
        return :local_only
      elsif self.remote_exists?
        return :remote_only
      else
        return :nowhere
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
      if at && ([at.year, at.month, at.day, at.hour, at.minute, at.second] == [now.year, now.month, now.day, 0, 0, 0])
        return @remote_updated_at = history[0][:timestamp]
      else
        return at
      end
    end


    def remote_updated_at=(value)
      if value
        value = DateTime.parse(value.to_s)
        value = DateTime.parse(value.to_s(:db) + DateTime.now.zone) if value.utc?
        @remote_updated_at = value
      end
    end


    def downloaded_at
      @downloaded_at
    end


    def downloaded_at=(value)
      if value
        value = DateTime.parse(value.to_s)
        value = DateTime.parse(value.to_s(:db) + DateTime.now.zone) if value.utc?
        @downloaded_at = value
      end
    end


    def history
      puts "--Getting page history for #{@name}"
      now = DateTime.now
      history = []
      page = @agent.get(@url + "/history")
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

    def read
      page = @agent.get(@url + "/edit")
      page.search("textarea")[0].text
    end


    def download_to(file)
      File.open(file, "w+:UTF-8") { |f| f.write(self.read) }
    end


    def download
      download_to(@local_file)
      self.downloaded_at = self.remote_updated_at
    end


    def write(text)
      now = DateTime.now
      page = @agent.get(@url + "/edit")
      form = page.form_with(:id=>"wiki_form")
      form.field_with(:name=>"content[text]").value = text
      result_page = form.submit
      errors = result_page.search("#errorExplanation li").map{ |li| li.text}
    end


    def write_from_file(file)
      write(File.open(file, "r:UTF-8").read)
    end

    
    def upload
      write_from_file(@local_file)
      self.downloaded_at = self.remote_updated_at = DateTime.now
    end


    def to_hash
      {
        :name => @name,
        :url => @url,
        :local_file => @local_file,
        :remote_updated_at => @remote_updated_at,
        :local_exists => local_exists?,
        :downloaded_at => @downloaded_at,
      }
    end


    def to_s
      str = "#<Redsync::WikiPage"
      str << " name = \"#{name}\"\n"
      str << " url = \"#{url}\"\n"
      str << " local_file = \"#{local_file}\"\n"
      str << " remote_exists? = #{remote_exists?}\n"
      str << " remote_updated_at = #{@remote_updated_at ? @remote_updated_at : "<never>"}\n"
      str << " local_exists? = #{local_exists?}\n"
      str << " local_updated_at = #{local_updated_at ? local_updated_at : "<never>"}\n"
      str << " downloaded_at = #{@downloaded_at ? @downloaded_at : "<never>"}\n"
      str << ">"
    end

    
  end
end
