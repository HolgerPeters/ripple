module Ripple
  module FigureSyntax
    PARTS_RE = /([,s])?(\?)?((?:[\d#bh_][\\`\+\-'!]*)+)?(?:\/(\d+[\.]*\*?\d*))?/
    CHORD_RE = /[\d#bh_][\\`\+\-'!]*/
    ALTERATION_RE = /[#bh`']/
    ALTERATION = {
      '#' => '_+',
      'b' => '_-',
      'h' => '_!',
      '`' => '\\\\',
      "'" => '/'
    }.freeze
    EXTENDERS_ON = '\\bassFigureExtendersOn'.freeze
    EXTENDERS_OFF = '\\bassFigureExtendersOff'.freeze

    HIDDEN_FORMAT = "\\once \\override BassFigure #'implicit = ##t".freeze

    def convert_figures(figures, _fn, _mode, _config)
      # remove comments
      figures = figures.gsub(/%([^\n]*)/, '')
      # split into figures
      figures = figures.split(/\s+/).reject(&:empty?)
      # breakdown figures
      figures = figures.map { |f| breakdown_figure(f) }
      # convert chords to arrays
      figures = figures.map { |f| convert_chord(f) }
      # transform syntax
      transform_figure_syntax(figures)
    end

    def breakdown_figure(f)
      a = f.match(PARTS_RE).to_a; a.shift; a
    end

    def convert_chord(f)
      if f[2]
        a = []; f[2].scan(CHORD_RE) { |i| a << i }
        [f[0], a, f[3], f[1]]
      else
        [f[0], nil, f[3], f[1]]
      end
    end

    def transform_chord(chord)
      chord.map { |n| n.gsub(ALTERATION_RE) { |a| ALTERATION[a] } }.join(' ')
    end

    def transform_tenues(figures)
      figures.each_with_index do |figure, fidx|
        chord = figure[1]; next unless chord
        chord.each_with_index do |n, i|
          # check for tenue
          next unless n == '_'
          figure[4] = true
          # back track to find tenue value
          number = nil
          a = figures[0, fidx]
          while !number && (f = a.pop) && (c = f[1])
            number = c[i] if c[i] != '_'
          end
          chord[i] = number if number
        end
      end
    end

    def transform_figure_syntax(figures)
      transform_tenues(figures)
      ext_mode = false
      transformed = figures.each_with_object([]) do |f, m|
        # check if extenders mode changed
        new_ext_mode = !!f[4]
        if ext_mode != new_ext_mode
          ext_mode = new_ext_mode
          m << (ext_mode ? EXTENDERS_ON : EXTENDERS_OFF)
        end
        m << HIDDEN_FORMAT if f[3] # hidden flag

        # add chord
        if f[0]
          m << "s#{f[2]}"
        elsif f[1]
          m << "<#{transform_chord(f[1])}>#{f[2]}"
        end
      end
      transformed.join(' ')
    end

    def load_figures(fn, mode, config)
      rpl_mode = fn =~ /\.fig$/
      figures = IO.read(fn)
      rpl_mode ? convert_figures(figures, fn, mode, config) : figures
    end

    class Proxy
      class << self
        include Ripple::FigureSyntax

        def cvt(figures, mode = nil, config = {})
          convert_figures(figures, '', mode, config)
        end
      end
    end

    def self.cvt(figures, mode = nil, config = {})
      Proxy.cvt(figures, mode, config)
    end
  end
end
