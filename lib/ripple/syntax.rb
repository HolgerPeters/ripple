module Ripple
  module Syntax
    SKIP_QUOTES_RE = /([^"]+)("[^"]+")?/m
    
    ACCIDENTAL = {'s' => 'is', 'b' => 'es', 'ss' => 'isis', 'bb' => 'eses'}
    #ACCIDENTAL_RE = /\b([a-g])([sb]{1,2})([^a-z])?/
    ACCIDENTAL_RE = /\b([a-g])([sb]{1,2})((?:\\[a-z]+)*)([^a-z])?/
    
    VALUE_RE = /([a-gr](?:[bs]*)(?:[',])*(?:[!\?])?)([36]4?)/
    VALUE = {'3' => '32', '6' => '16', '64' => '64'}
    
    TWOTHIRDS_RE = /(\d+)`/
    
    APPOGGIATURE_RE = /(\s)?\^([a-g])/

    PART_ONLY_RE = /\[\[((?:(?:\](?!\]))|[^\]])+)\]\]/m
    SCORE_ONLY_RE = /\{\{((?:(?:\}(?!\}))|[^\}])+)\}\}/m
    MIDI_ONLY_RE = /m\{\{((?:(?:\}(?!\}))|[^\}])+)\}\}/m
    PART_ONLY_CUE_RE = /\!\[\[((?:(?:\](?!\]))|[^\]])+)\]\]/m
    
    VARIABLE_RE = /%(\S+)%/
    DIVISI_RE = /\/1\s([^\/]+)\/2\s([^\/]+)\/u\s/
    
    BEAM_SLUR_RE = /([\[\(]+)([a-gr](?:[bs]*)(?:[',]*)(?:[!\?])?(?:[\d]*)[\.]{0,2}\|?`?(?:[\d*\/]*))/m
    
    def convert_prefixed_beams_and_slurs(m)
      m.gsub(BEAM_SLUR_RE) {"#{$2}#{$1}"}
    end
    
    CROSSBAR_DOT_RE = /((([a-gr](?:[bs]*))(?:[',]*))(?:[!\?])?((?:[\d]*)\.?(?:[\d*\/]*)))\.\|(\S*)/m
    CROSSBAR_DOT_VALUE = {'1' => '2', '2' => '4', '4' => '8', '8' => '16', '16' => '32'}
    CROSSBAR_NOTE = "\\once \\override NoteHead #'transparent = ##t \\once \\override Dots #'extra-offset = #'(-1.3 . 0) \\once \\override Stem #'transparent = ##t"
    CROSSBAR_TIE = "\\once \\override Tie #'transparent = ##t"
    
    def convert_crossbar_dot(m)
      m.gsub(CROSSBAR_DOT_RE) {
        "#{CROSSBAR_TIE} #{$1}#{$5} ~ #{CROSSBAR_NOTE} #{$3}#{$4}.*0 s#{CROSSBAR_DOT_VALUE[$4]}"
      }
    end
    
    INLINE_INCLUDE_RE = /\\inlineInclude\s(\S+)/
    
    def convert_inline_includes(m, fn, mode, config)
      m.gsub(INLINE_INCLUDE_RE) do |i|
        include_fn = File.join(File.dirname(fn), $1)
        load_music(include_fn, mode, config)
      end
    end
    
    MACRO_GOBBLE_RE = /([a-gr](?:[bs]?)(?:[,'!?]*))([\\\^_]\S+)?/
    MACRO_REPLACE_RE = /([#\@])([^\s]+)?/

    def convert_macro_region(pattern, m)
      size = pattern.count('#')
      accum = []; buffer = ''; last_note = nil
      m.gsub(MACRO_GOBBLE_RE) do |i|
        accum << [$1, $2]
        if accum.size == size
          buffer << pattern.gsub(MACRO_REPLACE_RE) do |i|
            note = ($1 == '@') ? last_note : accum.shift
            last_note = note
            "#{note[0]}#{$2}#{note[1]}"
          end
          buffer << " "
          accum = []
        end
      end
      buffer
    end
    
    INLINE_MACRO_RE = /\$\!([^\$]+)\$(?::([a-z0-9\._]+))?([^\$]+)(?:\$\$)?/m
    NAMED_MACRO_RE = /\$(?:([a-z0-9\._]+)\s)([^\$]+)(?:\$\$)?/m
    
    def convert_macros(m, config)
      m.gsub(INLINE_MACRO_RE) {
        config.set("macros/#{$2}", $1) if $2
        convert_macro_region($1, $3)
      }.gsub(NAMED_MACRO_RE) { |i|
        pattern = config.lookup("macros/#{$1}")
        if pattern.nil?
          raise RippleError, "Missing macro definition (#{$1})"
        end
        convert_macro_region(pattern, $2)
      }
    end
    
    def convert_modal_sections(m, mode)
      m.gsub(PART_ONLY_CUE_RE) {(mode == :part) ? "\\new CueVoice { #{$1} }" : ''}.
      gsub(MIDI_ONLY_RE) {(mode == :midi) ? $1 : ''}.
      gsub(PART_ONLY_RE) {(mode == :part) ? $1 : ''}.
      gsub(SCORE_ONLY_RE) {(mode == :score || mode == :midi) ? $1 : ''}
    end
    
    

    def _convert(kind, m, config)
      case kind
      when :crossbar_dot
        convert_crossbar_dot(m)
      when :prefixed_beams_and_slurs
        convert_prefixed_beams_and_slurs(m)
      when :variable
        m.gsub(VARIABLE_RE) {config[$1]}
      when :divisi
        m.gsub(DIVISI_RE) {"<< { \\voiceOne #{$1}} \\new Voice { \\voiceTwo #{$2}} >> \\oneVoice "}
      when :value
        m.gsub(VALUE_RE) {"#{$1}#{VALUE[$2]}"}
      when :twothirds
        m.gsub(TWOTHIRDS_RE) {"#{$1}*2/3"}
      when :accidental
        m.gsub(ACCIDENTAL_RE) {"#{$1}#{ACCIDENTAL[$2]}#{$3}#{$4}"}
      when :appogiature
        m.gsub(APPOGGIATURE_RE) {"#{$1}\\appoggiatura #{$2}"}
      else
        raise "Unknown conversion - #{kind}"
      end
    end
    
    def convert_syntax(m, fn, rpl_mode, mode, config)
      m = convert_modal_sections(m, mode)

      if rpl_mode
        m = m.gsub(SKIP_QUOTES_RE) do
          a,q = convert_macros($1, config), $2
          a = _convert(:prefixed_beams_and_slurs, a, config)
          a = _convert(:crossbar_dot, a, config)
          a = _convert(:variable, a, config)
          a = _convert(:divisi, a, config)
          a = _convert(:value, a, config)
          a = _convert(:twothirds, a, config)
          a = _convert(:accidental, a, config)
          a = _convert(:appogiature, a, config)
          "#{a}#{q}"
        end
      end
      
      convert_inline_includes(m, fn, mode, config)
    end
    
    def load_music(fn, mode, config, config_out = nil)
      rpl_mode = fn =~ /\.rpl$/
      content = IO.read(fn)
      if content =~ /^(---\s*\n.*?\n?)^(---\s*$\n?)/m
        content = content[($1.size + $2.size)..-1]
        config_out.merge!(convert_yaml($1)) if config_out
      end
      convert_syntax(content, fn, rpl_mode, mode, config)
    end
    
    class Proxy
      class << self
        include Ripple::Syntax
      
        def cvt(m, mode = nil, config = {})
          convert_syntax(m, '', true, mode, config)
        end
      end
    end
    
    def self.cvt(m, mode = nil, config = {})
      Proxy.cvt(m, mode, config)
    end
  end
end