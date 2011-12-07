# encoding:UTF-8

require 'rubygems'
require 'fileutils'
require 'uri'
require 'yaml'
require 'date'
require 'iconv'
require 'mechanize'
require 'active_support/all'

require 'redsync/cli'
require 'redsync/sync_stat'


class Redsync

  class Result
    DOWNLOADED = 1
    SKIPPED_UNKNOWN = 2
    SKIPPED_OLD = 4
    UPLOADED = 8
    CREATED = 16
    ERROR_ON_CREATE = 32
    ERROR_ON_EDIT = 64
  end


  def initialize(options)
    @config = {}
    @config.merge! options
    @config[:data_dir] = File.expand_path(@config[:data_dir])
    @config[:conflicts_dir] = File.join(@config[:data_dir], "__redsync_conflicts__")
    puts "Using data dir: #{@config[:data_dir]}"

    @login_url = @config[:url] + "/login"
    @config[:wiki_base_url] = @config[:url] + "/projects/" + @config[:project_slug] + "/wiki"

    initialize_system_files

    @agent = Mechanize.new
    @syncstat = SyncStat.new(@config, @agent)

    @logged_in = false
  end


  def initialize_system_files
    unless File.exist? @config[:data_dir]
      puts "Creating data dir"
      FileUtils.mkdir(@config[:data_dir]) 
    end
  end


  def login
    puts "Logging in as #{@config[:username]} to #{@login_url}..."
    page = @agent.get(@login_url)
    login_form = page.form_with(:action => "/login")
    login_form.field_with(:name => "username").value = @config[:username]
    login_form.field_with(:name => "password").value = @config[:password]
    result_page = login_form.submit
    if result_page.search("a.logout").any?
      puts "Logged in successfully."
      return true
    else
      puts "Login failed."
      return false
    end
  end


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
      Result::ERROR_ON_CREATE => 0,
      Result::ERROR_ON_EDIT => 0
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
    print " (#{results[Result::ERROR_ON_EDIT]} errors)" if results[Result::ERROR_ON_EDIT] > 0
    print "\n"
  end


  def upload(pagename, create = false)
    now = DateTime.now
    stat = @syncstat.for(pagename)
    puts (create ? "--Upload #{pagename}" : "--Create #{pagename}")

    page = @agent.get(@config[:wiki_base_url] + "/" + pagename + "/edit")
    form = page.form_with(:id=>"wiki_form")
    form.field_with(:name=>"content[text]").value = File.open(stat[:local_file], "r:UTF-8").read
    result_page = form.submit
    errors = result_page.search("#errorExplanation li").map{|li|li.text}

    if errors.any?
      print "--Error: #{pagename}: "
      puts errors
      return (create ? Result::ERROR_ON_EDIT : Result::ERROR_ON_CREATE)
    else
      now = DateTime.now
      @syncstat.update(pagename, {
        :downloaded_at => now,
        :remote_updated_at => now
      })
      return (create ? Result::UPLOADED : Result::CREATED)
    end
  end
end
