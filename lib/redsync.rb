# encoding:UTF-8

require 'fileutils'
require 'uri'
require 'yaml'
require 'mechanize'
require 'pry'

require 'redsync/cli'
require 'redsync/project'


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
    @projects = options[:projects].map do |pj|
      Project.new(
        :url => options[:url].sub(/^(.*?)\/?$/, '\1') + "/projects/#{pj}/wiki",
        :api_key => options[:api_key],
        :data_dir => File.join(options[:data_dir], pj),
        :extension => options[:extension]
      )
    end

    @agent = Mechanize.new
  end


  def status_check
    @projects.each do |pj|
      pj.status_check
    end
  end


  def sync_all
    @projects.each do |pj|
      pj.sync
    end
  end


  def interactive
    binding.pry
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
