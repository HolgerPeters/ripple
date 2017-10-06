module Ripple
  module Syntax
    SKIP_QUOTES_RE = /([^"]+)("[^"]+")?/m

    ACCIDENTAL = { 's' => 'is', 'b' => 'es', 'ss' => 'isis', 'bb' => 'eses' }.freeze
    # ACCIDENTAL_RE = /\b([a-g])([sb]{1,2})([^a-z])?/
    ACCIDENTAL_RE = /\b([a-g])([sb]{1,2})((?:\\[a-z]+)*)([^a-z])?/

    VALUE_RE = /([a-gr](?:[bs]*)(?:[',])*(?:[!\?])?)([36]4?)/
    VALUE = { '3' => '32', '6' => '16', '64' => '64' }.freeze

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
      m.gsub(BEAM_SLUR_RE) { "#{Regexp.last_match(2)}#{Regexp.last_match(1)}" }
    end

    CROSSBAR_DOT_RE = /((([a-gr](?:[bs]*))(?:[',]*))(?:[!\?])?((?:[\d]*)\.?(?:[\d*\/]*)))\.\|(\S*)/m
    CROSSBAR_DOT_VALUE = { '1' => '2', '2' => '4', '4' => '8', '8' => '16', '16' => '32' }.freeze
    CROSSBAR_NOTE = "\\once \\override NoteHead #'transparent = ##t \\once \\override Dots #'extra-offset = #'(-1.3 . 0) \\once \\override Stem #'transparent = ##t".freeze
    CROSSBAR_TIE = "\\once \\override Tie #'transparent = ##t".freeze

    def convert_crossbar_dot(m)
      m.gsub(CROSSBAR_DOT_RE) do
        "#{CROSSBAR_TIE} #{Regexp.last_match(1)}#{Regexp.last_match(5)} ~ #{CROSSBAR_NOTE} #{Regexp.last_match(3)}#{Regexp.last_match(4)}.*0 s#{CROSSBAR_DOT_VALUE[Regexp.last_match(4)]}"
      end
    end

    INLINE_INCLUDE_RE = /\\inlineInclude\s(\S+)/

    def convert_inline_includes(m, fn, mode, config)
      m.gsub(INLINE_INCLUDE_RE) do |_i|
        include_fn = File.join(File.dirname(fn), Regexp.last_match(1))
        load_music(include_fn, mode, config)
      end
    end

    MACRO_GOBBLE_RE = /([a-gr](?:[bs]?)(?:[,'!?]*))([\\\^_]\S+)?/
    MACRO_REPLACE_RE = /([#\@])([^\s]+)?/

    def convert_macro_region(pattern, m)
      size = pattern.count('#')
      accum = []; buffer = ''; last_note = nil
      m.gsub(MACRO_GOBBLE_RE) do |_i|
        accum << [Regexp.last_match(1), Regexp.last_match(2)]
        if accum.size == size
          buffer << pattern.gsub(MACRO_REPLACE_RE) do |_i|
            note = Regexp.last_match(1) == '@' ? last_note : accum.shift
            last_note = note
            "#{note[0]}#{Regexp.last_match(2)}#{note[1]}"
          end
          buffer << ' '
          accum = []
        end
      end
      buffer
    end

    INLINE_MACRO_RE = /\$\!([^\$]+)\$(?::([a-z0-9\._]+))?([^\$]+)(?:\$\$)?/m
    NAMED_MACRO_RE = /\$(?:([a-z0-9\._]+)\s)([^\$]+)(?:\$\$)?/m

    def convert_macros(m, config)
      m.gsub(INLINE_MACRO_RE) do
        config.set("macros/#{Regexp.last_match(2)}", Regexp.last_match(1)) if Regexp.last_match(2)
        convert_macro_region(Regexp.last_match(1), Regexp.last_match(3))
      end.gsub(NAMED_MACRO_RE) do |_i|
        pattern = config.lookup("macros/#{Regexp.last_match(1)}")
        raise RippleError, "Missing macro definition (#{Regexp.last_match(1)})" if pattern.nil?
        convert_macro_region(pattern, Regexp.last_match(2))
      end
    end

    def convert_modal_sections(m, mode)
      m.gsub(PART_ONLY_CUE_RE) { mode == :part ? "\\new CueVoice { #{Regexp.last_match(1)} }" : '' }
       .gsub(MIDI_ONLY_RE) { mode == :midi ? Regexp.last_match(1) : '' }
       .gsub(PART_ONLY_RE) { mode == :part ? Regexp.last_match(1) : '' }
       .gsub(SCORE_ONLY_RE) { mode == :score || mode == :midi ? Regexp.last_match(1) : '' }
    end

    def _convert(kind, m, config)
      case kind
      when :crossbar_dot
        convert_crossbar_dot(m)
      when :prefixed_beams_and_slurs
        convert_prefixed_beams_and_slurs(m)
      when :variable
        m.gsub(VARIABLE_RE) { config[Regexp.last_match(1)] }
      when :divisi
        m.gsub(DIVISI_RE) { "<< { \\voiceOne #{Regexp.last_match(1)}} \\new Voice { \\voiceTwo #{Regexp.last_match(2)}} >> \\oneVoice " }
      when :value
        m.gsub(VALUE_RE) { "#{Regexp.last_match(1)}#{VALUE[Regexp.last_match(2)]}" }
      when :twothirds
        m.gsub(TWOTHIRDS_RE) { "#{Regexp.last_match(1)}*2/3" }
      when :accidental
        m.gsub(ACCIDENTAL_RE) { "#{Regexp.last_match(1)}#{ACCIDENTAL[Regexp.last_match(2)]}#{Regexp.last_match(3)}#{Regexp.last_match(4)}" }
      when :appogiature
        m.gsub(APPOGGIATURE_RE) { "#{Regexp.last_match(1)}\\appoggiatura #{Regexp.last_match(2)}" }
      else
        raise "Unknown conversion - #{kind}"
      end
    end

    def convert_syntax(m, fn, rpl_mode, mode, config)
      m = convert_modal_sections(m, mode)

      if rpl_mode
        m = m.gsub(SKIP_QUOTES_RE) do
          a = convert_macros(Regexp.last_match(1), config)
          q = Regexp.last_match(2)
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
        content = content[(Regexp.last_match(1).size + Regexp.last_match(2).size)..-1]
        config_out.merge!(convert_yaml(Regexp.last_match(1))) if config_out
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
