# encoding:UTF-8

require 'rubygems'
require 'fileutils'
require 'uri'
require 'yaml'
require 'date'
require 'iconv'
require 'mechanize'
require 'active_support/all'


class Redsync

  class Status
    DOWNLOADED = 1
    SKIPPED_UNKNOWN = 2
    SKIPPED_OLD = 4
    UPLOADED = 8
    CREATED = 16
    ERROR_ON_CREATE = 32
    ERROR_ON_EDIT = 64
  end

  # Options:
  # :url => Redmine root URL
  # :project_slug => Your project slug
  # :username
  # :password
  # :verbose => Output verbose logs
  def initialize(options)
    @config = {
      :data_dir => "data",
    }
    @config.merge! options
    @config[:data_dir] = File.expand_path(@config[:data_dir])
    @config[:conflicts_dir] = File.join(@config[:data_dir], "__redsync_conflicts__")
    @config[:pages_list_file] = File.join(@config[:data_dir], "__redsync_pages_list__.yml")
    puts "Using data dir: #{@config[:data_dir]}"

    @login_url = @config[:url] + "/login"
    @wiki_base_url = @config[:url] + "/projects/" + @config[:project_slug] + "/wiki"

    initialize_system_files
    recover_pages_list

    @agent = Mechanize.new
    @logged_in = false
  end

  
  def initialize_system_files
    FileUtils.mkdir(@config[:data_dir]) unless File.exist? @config[:data_dir]
    FileUtils.mkdir(@config[:conflicts_dir]) unless File.exist? @config[:conflicts_dir]
    FileUtils.touch(@config[:pages_list_file]) unless File.exist? @config[:pages_list_file]
  end


  def login
    puts "Logging in as #{@config[:username]} to #{@login_url}..."
    page = @agent.get(@login_url)
    login_form = page.form_with(:action => "/login")
    login_form.field_with(:name => "username").value = @config[:username]
    login_form.field_with(:name => "password").value = @config[:password]
    result_page = login_form.submit
    if result_page.link_with(:text => "Sign out")
      puts "Logged in successfully."
      return true
    else
      puts "Login failed."
      return false
    end
  end


  def pages
    refresh_pages_list if (!@pages || @pages.empty?)
    @pages
  end


  def downsync
    puts "\nDownsync:"
    statuses = {
      Status::DOWNLOADED => 0,
      Status::SKIPPED_OLD => 0,
      Status::SKIPPED_UNKNOWN => 0,
    }
    pages.each do |pagename, info|
      statuses[downsync_page(pagename)] += 1
    end
    puts "Downloaded #{statuses[Status::DOWNLOADED]} pages."
    puts "Skipped #{statuses[Status::SKIPPED_OLD] + statuses[Status::SKIPPED_UNKNOWN]} pages."
  end


  def downsync_page(pagename)
    now = DateTime.now

    page_info = pages[pagename]
    if !page_info
      puts "--Skipping #{pagename}: unknown page"
      return Status::SKIPPED_UNKNOWN
    end

    filename = File.join(@config[:data_dir], "#{pagename}.txt")

    if File.exist? filename
      local_updated_at = File.stat(filename).mtime.to_datetime
      remote_updated_at = DateTime.parse(page_info[:updated_at_str] + "T00:00:00" + now.zone)
      if remote_updated_at.year == now.year && remote_updated_at.month == now.month && remote_updated_at.day == now.day
        remote_updated_at = page_history(pagename)[0][:timestamp]
      end
      if local_updated_at >= remote_updated_at
        puts "--Skip #{pagename}: local (#{local_updated_at}) is newer than remote (#{remote_updated_at})" if @config[:verbose]
        return Status::SKIPPED_OLD
      end
    end

    puts "--Download #{pagename}"
    page = @agent.get(page_info[:url] + "/edit")
    File.open(filename, "w+:UTF-8") { |f| f.write(page.search("textarea")[0].text) }
    @pages[pagename][:downloaded_at] = File.stat(filename).mtime.to_datetime
    write_pages_list

    return Status::DOWNLOADED
  end


  def upsync
    puts "\nUpsync:"
    statuses = {
      Status::UPLOADED => 0,
      Status::SKIPPED_OLD => 0,
      Status::CREATED => 0,
      Status::ERROR_ON_CREATE => 0,
      Status::ERROR_ON_EDIT => 0
    }
    Dir.entries(@config[:data_dir]).each do |file|
      fullpath = File.join(@config[:data_dir], file)
      next if File.directory?(fullpath)
      next if file =~ /^__redsync_/
      file = Iconv.iconv("UTF-8", "UTF-8-MAC", file).first
      statuses[upsync_page(File.basename(file, ".txt"))] += 1
    end
    print "Created #{statuses[Status::CREATED]} pages."
    print " (#{statuses[Status::ERROR_ON_CREATE]} errors)" if statuses[Status::ERROR_ON_CREATE] > 0
    print "\n"
    print "Uploaded #{statuses[Status::UPLOADED]} pages."
    print " (#{statuses[Status::ERROR_ON_EDIT]} errors)" if statuses[Status::ERROR_ON_EDIT] > 0
    print "\n"
    puts "Skipped #{statuses[Status::SKIPPED_OLD]} pages."
  end


  def upsync_page(pagename)
    now = DateTime.now
    page_info = pages[pagename]
    filename = File.join(@config[:data_dir], "#{pagename}.txt")
    local_updated_at = File.stat(filename).mtime.to_datetime

    if page_info.try(:[], :downloaded_at) && local_updated_at <= page_info[:downloaded_at].to_datetime
      puts "--Skip #{pagename}" if @config[:verbose]
      return Status::SKIPPED_OLD
    end

    puts (page_info ? "--Upload #{pagename}" : "--Create #{pagename}")
    page = @agent.get(@wiki_base_url + "/" + pagename + "/edit")
    form = page.form_with(:id=>"wiki_form")
    form.field_with(:name=>"content[text]").value = File.open(filename, "r:UTF-8").read
    result_page = form.submit
    errors = result_page.search("#errorExplanation li").map{|li|li.text}
    if errors.any?
      print "--Error: #{pagename}: "
      puts errors
      return (page_info ? Status::ERROR_ON_EDIT : Status::ERROR_ON_CREATE)
    else
      now = DateTime.now
      pages[pagename] ||= {}
      pages[pagename][:name] = pagename
      pages[pagename][:url] = @wiki_base_url + "/" + URI.encode(pagename)
      pages[pagename][:downloaded_at] = now
      pages[pagename][:updated_at_str] = now.strftime("%Y-%m-%d")
      write_pages_list
      return (page_info ? Status::UPLOADED : Status::CREATED)
    end
  end


  def refresh_pages_list
    puts "Refreshing pages list"
    @pages ||= {}
    page = @agent.get(@wiki_base_url + "/date_index")

    page.search("#content h3").each do |h3|
      links = h3.next_element.search("a")
      links.each do |link|
        page_url = @config[:url] + link.attr("href")
        pagename = URI.decode(page_url.match(/^#{@wiki_base_url}\/(.*)$/)[1]).force_encoding("UTF-8")
        @pages[pagename] ||= {}
        @pages[pagename][:name] = pagename
        @pages[pagename][:url] = page_url
        @pages[pagename][:updated_at_str] = h3.text
      end
    end

    @pages
  end


  def recover_pages_list
    @pages = YAML.load_file(@config[:pages_list_file])
    @pages ||= {}
  end


  def write_pages_list
    File.open(@config[:pages_list_file], "w+:UTF-8") do |f|
      f.write(@pages.to_yaml)
    end
  end


  def page_history(pagename)
    puts "--Getting page history for #{pagename}" if @config[:verbose]
    history = []
    page = @agent.get(@wiki_base_url + "/" + URI.encode(pagename) + "/history")
    page.search("table.wiki-page-versions tbody tr").each do |tr|
      timestamp = DateTime.parse(tr.search("td")[3].text+"+0900") 
      author_name = tr.search("td")[4].text.strip
      history << {
        :timestamp => timestamp,
        :author_name => author_name
      }
    end
    history
  end
end
