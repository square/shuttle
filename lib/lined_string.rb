
class LinedString < String

  # @param [String] The string to operate on.
  def initialize(string)
    @text = string
    @offset = 0
    @last_write = 0
  end

  # @param [Array<Integer>] The 2D coordinates of the beginning and end of the
  #   desired string.
  def read(start, finish)
    start = convert(start)
    finish = convert(finish)

    text[start..finish]
  end

  # Saves all changes and creates a new coordinate system according to the
  # current state of the text.
  def render
    @offset = 0
    @lines = nil
    @cum_lengths = nil
  end

  # @param [Array<Integer>] The 2D coordinates of the beginning and end of the
  #   region to write to.
  # @param [String] The text to replace the region with.
  def write(start, finish, new_text)
    # Convert to true postitions
    start = convert(start) + @offset
    finish = convert(finish) + @offset

    if start < @last_write
      raise "Can't rewrite a position"
    end

    text[start...finish] = new_text
    @offset += new_text.length - (finish - start)
    @last_write = finish + new_text.length - (finish - start)
    new_text
  end

  # @return [String] The text.
  def text
    @text
  end

  # @return [Array<String>] The lines of the text, with newlines.
  def lines
    @lines ||= @text.split("\n").map { |l| l + "\n" }
  end

  # @private
  #
  # @return [Array<Integer>] The cumulative sum of line lengths, starting at 0.
  def cum_lengths
    @cum_lengths if @cum_lengths
    cum = 0
    @cum_lengths = lines.map { |l| prev = cum ; cum += l.length ; prev }
  end

  # Mimics the behavior of String#match, but returned MatchData will report
  # character positions in 2D coordinates.
  #
  # @param [Regex, String] The pattern to match.
  # @param [Array<Integer>] The postition to begin the search at.
  # @return [MatchData]
  def match(pattern, coord=[1,0])
    # Patch m to use 2D coordinates
    pos = convert(coord)
    make_lined(text.match(pattern, pos), self)
  end

  # @private
  #
  # @param [Integer, Array] Either the 1D position or 2D coordinate to convert.
  # @return [Array, Integer] The converted position or coordinate in the
  #   original coordinate system (i.e. before any writes).
  def convert(a)
    if Integer === a # 1D to 2D
      cum, ind = cum_lengths.reverse.each_with_index.detect { |len, i| len < a }
      [lines.count - ind, a - cum]
    elsif Array === a # 2D to 1D
      cum_lengths[a[0] - 1] + a[1]
    end
  end

  # @private
  #
  # @param [MatchData] A match result to be overridden to return 2D coordinates.
  def make_lined(m, lined_string)
    m.instance_variable_set(:@lined_string, lined_string)
    class << m
      [:begin, :end].each { |f|
        alias_method :"old_#{f}", f
        define_method(f) { |n| @lined_string.convert(send(:"old_#{f}", n)) }
      }

      alias_method :old_offset, :offset
      def offset(n)
        old_offset(n).map { |p| @lined_string.convert(p) }
      end
    end
    m
  end
end
