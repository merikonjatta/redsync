require 'optparse'
require 'yaml'
require 'redsync'
require 'ir_b'

class Redsync
  class CLI
    class << self

      def run
        parse_options
        check_config_file

        redsync = Redsync.new(YAML.load_file(@options.delete(:config_file)).merge(@options))
        exit unless redsync.login

        if @options[:interactive]
          ir b
        else
          time do
            redsync.sync_all
          end
        end
      end


      def parse_options
        @options = {
          :config_file => "~/redsync.yml",
        }

        OptionParser.new do |opts|
          opts.banner = "Usage: redsync [options]"
          opts.on("-v", "--[no-]verbose", "Output verbose logs") do |v|
            @options[:verbose] = v
          end
          opts.on("-c", "--config FILE", "Use specified config file instead of ~/redsync.yml") do |file|
            @options[:config_file] = file
          end
          opts.on("-u", "--upsync-only", "Upsync only, don't downsync") do |v|
            @options[:uponly] = v
          end
          opts.on("-d", "--downsync-only", "Downsync only, don't upsync") do |v|
            @options[:downonly] = v
          end
          opts.on("-i", "--interactive", "Interactive mode (irb)") do |v|
            @options[:interactive] = v
          end
          opts.on("-D", "--debug", "Debug mode. Requires ruby-debug19") do |v|
            @options[:debug] = v
          end
        end.parse!

        if @options[:debug]
          require 'ruby-debug'
          Debugger.settings[:autoeval] = true
          Debugger.settings[:reload_source_on_change] = true
        end

        @options[:config_file] = File.expand_path(@options[:config_file])
      end


      def check_config_file
        if !File.exist? @options[:config_file]
          Redsync::CLI.confirm("Config file #{@options[:config_file]} doesn't exist. Create?") do 
            FileUtils.cp("config.yml.dist", @options[:config_file]) 
            puts "Creating config file in #{@options[:config_file]}."
            puts "Edit it and call me again when you're done."
          end
          exit
        end
      end
      

      def confirm(question, default_yes = true, &block)
        print question
        print (default_yes ? " [Y/n] " : " [N/y] ")
        c = gets.strip
        result = 
          if c =~ /^$/
            default_yes
          else
            c =~ /^y/i
          end
        block.call if result && block
      end

      
      def time(&block)
        start = Time.now
        yield
        puts "Finished in #{Time.now - start} seconds."
      end

    end
  end
end
