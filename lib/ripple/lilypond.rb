class LilypondError < RuntimeError
end

module Ripple
  module Lilypond
    def self.delete_ps_file(pdf_file)
      FileUtils.rm("#{pdf_file}.ps") rescue nil
    end
    
    def self.run(args)
      IO.popen("ly #{args}", 'w+') {}
      case $?.exitstatus
      when nil:
        puts
        puts "Interrupted by user"
        exit
      when 0: # success, do nothing
      else
        raise LilypondError
      end
    end
    
    def self.make_pdf(ly_file, pdf_file, config)
      run("--pdf -o \"#{pdf_file}\" \"#{ly_file}\"")
      delete_ps_file(pdf_file)
      system "open #{pdf_file}.pdf" if config["open_target"]
    end
    
    def self.make_midi(ly_file, midi_file, config)
      run("-o \"#{midi_file}\" \"#{ly_file}\"")
      system "open #{midi_file}.midi" if config["open_target"]
    end
  end
end