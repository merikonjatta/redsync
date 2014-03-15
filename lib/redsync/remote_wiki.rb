require 'mechanize'
require 'uri'

class Redsync
  class RemoteWiki
    def initialize(options)
      @url = options[:url]
      @api_key = options[:api_key]
      @agent = Mechanize.new
    end

    def list
      unless @pages
        @pages = {}

        index = @agent.get(@url + "/index.xml?key=#{@api_key}")
        index.xml.at("wiki_pages").children.each do |node|
          name = node.at("title").text
          @pages[name] = WikiPage.new(
            :name => name,
            :mtime => Time.parse(node.at("updated_on").text),
          )
        end
      end

      @pages.values
    end

    def get(name)
      list unless @pages

      return nil if @pages[name].nil?

      unless @pages[name].content
        page = @agent.get(@url + "/#{URI.encode(name)}.xml?key=#{@api_key}")
        @pages[name].content = page.at("text").text
      end

      @pages[name]
    end


    def write(name, content)
      doc = Nokogiri::XML::Document.new
      wiki_page = Nokogiri::XML::Node.new("wiki_page", doc)

      text = Nokogiri::XML::Node.new("text", doc)
      text.content = content

      comments = Nokogiri::XML::Node.new("comments", doc)
      comments.content = "Uploaded by Redsync"

      doc << wiki_page
      wiki_page << text
      wiki_page << comments
      
      @agent.put(@url + "/#{URI.encode(name)}.xml?key=#{@api_key}", doc.to_s, 'Content-Type' => "text/xml")
    end
  end
end

