require 'yaml'
require 'fileutils'
require 'redsync/local_wiki'
require 'redsync/remote_wiki'
require 'redsync/wiki_page'

class Redsync
  class Project
    
    def initialize(options)
      @url = options[:url]
      @api_key = options[:api_key]
      @data_dir = File.expand_path(options[:data_dir])
      @extension = options[:extension] || "txt"

      initialize_system_files

      @syncstat = {}
      @syncdone = {}
      @syncstat_file = File.join(@data_dir, "__redsync_syncstat.yml")
      load_syncstat

      @remote_wiki = RemoteWiki.new(url: @url, api_key: @api_key)
      @local_wiki = LocalWiki.new(data_dir: @data_dir, extension: @extension)
    end


    def initialize_system_files
      unless File.exist? @data_dir
        puts "Creating #{@data_dir}"
        FileUtils.mkdir_p(@data_dir) 
      end
    end


    def load_syncstat
      @syncstat = {}
      @syncdone = {}
      return unless File.exist? @syncstat_file
      @syncstat = YAML.load_file(@syncstat_file)
    end


    def save_syncstat
      File.open(@syncstat_file, "w+:UTF-8") do |f|
        f.write(@syncstat.to_yaml)
      end
    end


    def status_check
    end

    
    def sync
      downsync
      upsync
      cleanup
    end


    def downsync
      @remote_wiki.list.each do |page|
        next if @syncdone[page.name]
        if @syncstat[page.name].nil? || page.mtime > @syncstat[page.name] && page.mtime > @local_wiki.get(page.name).mtime
          download(page.name)
        end
      end
    end


    def upsync
      @local_wiki.list.each do |page|
        next if @syncdone[page.name]
        if @syncstat[page.name].nil? || page.mtime > @syncstat[page.name] && page.mtime > @remote_wiki.get(page.name).mtime
          upload(page.name)
        end
      end
    end


    def cleanup
      @syncstat.each do |name, timestamp|
        next if @syncdone[name]
        if @local_wiki.get(name).nil? && @remote_wiki.get(name)
          delete_remote(name)
        end

        if @local_wiki.get(name) && @remote_wiki.get(name).nil?
          delete_local(name)
        end

        if @local_wiki.get(name).nil? && @remote_wiki.get(name).nil?
          @syncstat.delete(name)
          save_syncstat
        end
      end
    end


    def download(name)
      puts "Downloading:\t#{name}"
      @local_wiki.write(name, @remote_wiki.get(name).content)
      @syncstat[name] = Time.new
      @syncdone[name] = true
      save_syncstat
    end


    def upload(name)
      puts "Uploading:\t#{name}"
      @remote_wiki.write(name, @local_wiki.get(name).content)
      @syncstat[name] = Time.new
      @syncdone[name] = true
      save_syncstat
    end


    def delete_local(name)
      puts "Deleted on redmine:\t#{name}"
    end

    
    def delete_remote(name)
      puts "Deleted locally:\t#{name}"
    end


    def to_s
      str = "#<Redsync::Project"
      str << " url = \"#{@url}\"\n"
      str << " data_dir = \"#{@data_dir}\"\n"
      str << " extension = \"#{@extension}\"\n"
      str << " pages = #{@syncstat.count}\n"
      str << ">"
    end

  end
end
