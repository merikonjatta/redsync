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


  def status_check
    @projects.each do |project_identifier|
      wiki = @wikis[project_identifier]
      wiki.load_pages_cache
      wiki.scan

      puts "#{wiki.pages_to_download.length} pages to download"
      puts "#{wiki.pages_to_create.length} pages to create"
      puts "#{wiki.pages_to_upload.length} pages to upload"
    end
  end


  def sync_all
    @projects.each do |project_identifier|
      sync(project_identifier)
    end
  end


  def sync(project_identifier)
    wiki = @wikis[project_identifier]
    wiki.load_pages_cache
    wiki.scan
    wiki.downsync
    wiki.upsync
  end


  def interactive
    wikis.each do |project_identifier, wiki|
      wiki.load_pages_cache
      wiki.scan
    end
    ir b
  end


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
