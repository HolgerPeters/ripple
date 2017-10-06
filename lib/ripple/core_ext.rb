class Integer
  ROMAN = %w[0 I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX
             XX XXI XXII XXIII XXIV XXV XXVI XXVII XXVIII XXIX XXX].freeze

  def to_roman
    ROMAN[self]
  end
end

class String
  def titlize(all_capitals = false)
    all_capitals ?
      tr('-', ' ').gsub(/\b('?[a-z])/) { Regexp.last_match(1).capitalize } :
      tr('-', ' ').capitalize
  end

  def to_movement_title
    case self
    when /^\-\d+\-(.+)$/
      Regexp.last_match(1).titlize(true)
    when /^(\d+)\-(.+)$/
      "#{Regexp.last_match(1).to_i}. #{Regexp.last_match(2).titlize(true)}"
    when /^(\d+)$/
      num = Regexp.last_match(1).to_i.to_roman
    else
      self
    end
  end

  def to_instrument_title
    if self =~ /^([^\d]+)(\d+)$/
      "#{Regexp.last_match(1).titlize} #{Regexp.last_match(2).to_i.to_roman}"
    else
      titlize
    end
  end

  # Works like inspect, except it unescapes Unicode sequences
  def ly_inspect
    inspect.gsub(/(\\(\d{3}))/) { [Regexp.last_match(2).oct].pack('c') }
  end
end

class Hash
  # Merges self with another hash, recursively.
  #
  # This code was lovingly stolen from some random gem:
  # http://gemjack.com/gems/tartan-0.1.1/classes/Hash.html
  #
  # Thanks to whoever made it.
  def deep_merge(hash)
    target = Marshal.load(Marshal.dump(self))
    target.deep_merge!(hash)
  end

  def deep_merge!(hash)
    hash.keys.each do |key|
      if hash[key].is_a?(Hash) && self[key].is_a?(Hash)
        self[key] = self[key].deep_merge!(hash[key])
        next
      end

      self[key] = hash[key]
    end

    self.deep = true
    self
  end

  def lookup(path)
    path.split('/').inject(self) { |m, i| m[i].nil? ? (return nil) : m[i] }
  end

  def set(path, value)
    leafs = path.split('/')
    k = leafs.pop
    h = leafs.inject(self) { |m, i| m[i].is_a?(Hash) ? m[i] : (m[i] = {}) }
    h[k] = value
  end

  attr_accessor :deep

  alias old_get []
  def [](k)
    if @deep && k.is_a?(String) && k =~ /\//
      lookup(k)
    else
      old_get(k)
    end
  end

  alias old_set []=
  def []=(k, v)
    if @deep && k.is_a?(String) && k =~ /\//
      set(k, v)
    else
      old_set(k, v)
    end
  end

  alias old_merge merge
  def merge(hash)
    if deep || hash.deep
      deep_merge(hash)
    else
      old_merge(hash)
    end
  end

  alias old_merge! merge!
  def merge!(hash)
    if deep || hash.deep
      deep_merge!(hash)
    else
      old_merge!(hash)
    end
  end
end

class Array
  # Returns the index of an array of items inside the array:
  #
  #   [1,2,3,4,5].array_index([3,4]) #=> 2
  #   [1,2,3,4,5].array_index([3,5]) #=> nil
  def array_index(arr)
    f = arr[0]
    return nil unless idx = index(f)
    return idx if self[idx, arr.size] == arr
  end
end

module Kernel
  # Simple debugging tool. Returns a backtrace to the current place.
  def backtrace
    raise
  rescue => e
    b = e.clean_backtrace
    b.shift
    b
  end

  def load_yaml(fn)
    convert_yaml(IO.read(fn))
  rescue
    {}
  end

  def convert_yaml(s)
    o = begin
          YAML.safe_load(s)
        rescue
          {}
        end
    o == false ? {} : o
  end
end

class Exception
  def clean_backtrace
    stop = nil
    return [] if backtrace.nil?
    backtrace.each_with_object([]) do |i, m|
      unless stop
        m << i
        stop = i !~ /bin/
      end
    end
  end
end

class RippleError < RuntimeError
end
