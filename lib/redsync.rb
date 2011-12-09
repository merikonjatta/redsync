# encoding:UTF-8

require 'rubygems'
require 'fileutils'
require 'uri'
require 'yaml'
require 'date'
require 'iconv'
require 'mechanize'
require 'active_support/all'
require 'ir_b'

require 'redsync/cli'
require 'redsync/wiki'
require 'redsync/wiki_page'


class Redsync

  attr_reader :url,
              :projects,
              :username,
              :data_dir,
              :extension,
              :wikis

  # Valid options:
  #   :url => Redmine's base URL. Required.
  #   :projects => List of target projects. Required.
  #   :username => Redmine username. Required.
  #   :password => Redmine password. Required.
  #   :data_dir => Directory to read/write. Required.
  #   :extension => Filename extensions. Defaults to "txt"
  def initialize(options)
    options = {
      :extension => "txt",
    }.merge(options)
    
    @url = options[:url].match(/(.*?)\/?$/)[1]
    @projects = options[:projects]
    @username = options[:username]
    @password = options[:password]
    @data_dir = File.expand_path(options[:data_dir])
    @extension = options[:extension]

    @login_url = @url + "/login"

    initialize_system_files

    @agent = Mechanize.new
  end


  def initialize_system_files
    if File.exist? @data_dir
      puts "Using data dir: #{@data_dir}"
    else
      puts "Creating #{@data_dir}"
      FileUtils.mkdir(@data_dir) 
    end
  end


  def login
    puts "Logging in as #{@username} to #{@login_url}..."
    page = @agent.get(@login_url)
    login_form = page.form_with(:action => "/login")
    login_form.field_with(:name => "username").value = @username
    login_form.field_with(:name => "password").value = @password
    result_page = login_form.submit
    if result_page.search("a.logout").any?
      puts "Logged in successfully."
      instantiate_wikis
      return true
    else
      puts "Login failed."
      return false
    end
  end


  def instantiate_wikis
    @wikis = @projects.inject({}) do |sum, project_identifier|
      sum[project_identifier] = Wiki.new({
        :url => @url + "/projects/" + project_identifier + "/wiki",
        :cookies => @agent.cookie_jar.cookies(URI.parse(@url)),
        :data_dir => File.join(@data_dir, project_identifier),
        :extension => @extension
      })
      sum
    end
  end


  def sync_all
    @projects.each do |project_identifier|
      downsync(project_identifier)
    end
  end


  def downsync(project_identifier)
    wiki = @wikis[project_identifier]
    wiki.scan_remote
    debugger;true
  end


  def interactive
    wikis.each do |project_identifier, wiki|
      wiki.load_pages_cache
      wiki.scan_remote
    end
    ir b
  end


=begin
  def downsync
    @syncstat.refresh
    puts "\nDownsync:"
    statuses = {
      Result::DOWNLOADED => 0,
    }
    @syncstat.remote_updated_page_names.each do |pagename|
      statuses[download(pagename)] += 1
    end
    puts "Downloaded #{statuses[Result::DOWNLOADED]} pages."
  end


  def download(pagename)
    stat = @syncstat.for(pagename)

    puts "--Download #{pagename}"
    page = @agent.get(stat[:url] + "/edit")
    File.open(stat[:local_file], "w+:UTF-8") { |f| f.write(page.search("textarea")[0].text) }
    @syncstat.update(pagename, :downloaded_at => File.stat(stat[:local_file]).mtime.to_datetime)

    return Result::DOWNLOADED
  end


  def upsync
    puts "\nUpsync:"
    results = {
      Result::UPLOADED => 0,
      Result::CREATED => 0,
      Result::ERROR_ON_UPLOAD => 0,
      Result::ERROR_ON_CREATE => 0,
    }
    @syncstat.new_page_names.each do |pagename|
      results[upload(pagename, true)] += 1
    end
    @syncstat.local_updated_page_names.each do |pagename|
      results[upload(pagename)] += 1
    end
    print "Created #{results[Result::CREATED]} pages."
    print " (#{results[Result::ERROR_ON_CREATE]} errors)" if results[Result::ERROR_ON_CREATE] > 0
    print "\n"
    print "Uploaded #{results[Result::UPLOADED]} pages."
    print " (#{results[Result::ERROR_ON_UPLOAD]} errors)" if results[Result::ERROR_ON_UPLOAD] > 0
    print "\n"
  end


  def upload(pagename, create = false)
    now = DateTime.now
    stat = @syncstat.for(pagename)
    puts (create ? "--Create #{pagename}" : "--Upload #{pagename}")

    page = @agent.get(@config[:wiki_base_url] + "/" + pagename + "/edit")
    form = page.form_with(:id=>"wiki_form")
    form.field_with(:name=>"content[text]").value = File.open(stat[:local_file], "r:UTF-8").read
    result_page = form.submit
    errors = result_page.search("#errorExplanation li").map{|li|li.text}

    if errors.any?
      print "--Error: #{pagename}: "
      puts errors
      return (create ? Result::ERROR_ON_CREATE : Result::ERROR_ON_UPLOAD)
    else
      now = DateTime.now
      @syncstat.update(pagename, {
        :downloaded_at => now,
        :remote_updated_at => now
      })
      return (create ? Result::CREATED : Result::UPLOADED)
    end
  end
=end
  def to_s
    str = "#<Redsync"
    str << " url = \"#{@url}\"\n"
    str << " username = \"#{@username}\"\n"
    str << " projects = \"#{@projects}\"\n"
    str << " data_dir = \"#{@data_dir}\"\n"
    str << " extension = \"#{@extension}\"\n"
    str << ">"
  end

end
