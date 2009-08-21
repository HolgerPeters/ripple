module Ripple
  module Syntax
    ACCIDENTAL = {'s' => 'is', 'b' => 'es', 'ss' => 'isis', 'bb' => 'eses'}
    ACCIDENTAL_RE = /\b([a-g])([sb]{1,2})([^a-z])?/
    
    VALUE_RE = /\b([ra-g])([^\s]+)?([36])([^\d\w])?/
    VALUE = {'3' => '32', '6' => '16'}
    
    BEAM_SLUR_RE = /([^\s\[]*)([\[\(])(\s?[^\s]*)/
    BEAM_SLUR_INNER_RE = /([^\s]+)(.*)/
    
    APPOGGIATURE_RE = /(\s)?\^([a-g])/
    
    def convert_rpl(m)
      m = m.gsub(ACCIDENTAL_RE) {"#{$1}#{ACCIDENTAL[$2]}#{$3}"}
      # m = m.gsub(BEAM_SLUR_RE) {"#{$1}#{$4}#{$2}"}
      m = m.gsub(VALUE_RE) {"#{$1}#{$2}#{VALUE[$3]}#{$4}"}
      m = m.gsub(APPOGGIATURE_RE) {"#{$1}\\appoggiatura #{$2}"}
      m = m.gsub(BEAM_SLUR_RE) do |i| 
        pre, sign, post = $1, $2, $3
        (pre.empty? && post =~ BEAM_SLUR_INNER_RE) ?
          "#{$1}#{sign}#{$2}" : i
      end
      m
    end
    
    def load_music(fn)
      m = IO.read(fn)
      fn =~ /\.rpl$/ ? convert_rpl(m) : m
    end
  end
end