module Ripple
  module LyricsSyntax
    LYRICS_RE = /([^\\-_])(?:([\-]+)|([_]+))/
    ESCAPE_RE = /\\(_|\-)/

    def convert_lyrics(lyrics, _fn, _mode, _config)
      lyrics.gsub(LYRICS_RE) do
        if Regexp.last_match(2)
          "#{Regexp.last_match(1)} -- #{'_ ' * (Regexp.last_match(2).size - 1)}"
        elsif Regexp.last_match(3)
          "#{Regexp.last_match(1)} __ #{'_ ' * (Regexp.last_match(3).size - 1)}"
        end
      end.gsub(ESCAPE_RE) { Regexp.last_match(1) }
    end

    def load_lyrics(fn, mode, config)
      rpl_mode = fn =~ /\.lyr(\d*)$/
      lyrics = IO.read(fn)
      rpl_mode ? convert_lyrics(lyrics, fn, mode, config) : lyrics
    end

    class Proxy
      class << self
        include Ripple::LyricsSyntax

        def cvt(lyrics, mode = nil, config = {})
          convert_lyrics(lyrics, '', mode, config)
        end
      end
    end

    def self.cvt(lyrics, mode = nil, config = {})
      Proxy.cvt(lyrics, mode, config)
    end
  end
end
