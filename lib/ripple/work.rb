require 'find'

module Ripple
  class Work
    attr_reader :path, :config
    
    def initialize(path, config = {})
      @path = File.expand_path(path)
      @config = config.merge(work_config)
    end
    
    def relative_path
      root = File.expand_path(config["source"])
      path =~ /^#{root}\/(.+)$/ && $1
    end
    
    def work_config
      YAML.load(IO.read(File.join(@path, "_work.yml"))) rescue {}
    end
    
    def movements
      @movements ||= Dir[File.join(@path, "**")].
        reject {|fn| !File.directory?(fn)}.map do |fn|
          fn =~ /^#{@path}\/(.+)$/ && $1
        end.sort
    end
    
    def parts
      return @parts if @parts
      @parts = Dir[File.join(@path, "**/*.rpl")].
        reject {|fn| !File.file?(fn) || File.basename(fn) =~ /^_/}.map do |fn|
          File.basename(fn, ".rpl")
        end
      @config.lookup("parts").each do |p, opts|
        @parts << p unless opts["ignore"]
      end
      @parts.uniq!.sort!
    end
    
    def process(opts = {})
      parts.each {|p| Part.new(p, self).process}
      if parts.size > 1
        Score.new(self).process
      end
    end
  end
end