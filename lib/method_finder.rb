require 'rubygems'
require 'ripper'
require 'lined_string'

class MethodFinder

  # @param [String] The code that we wish to search within.
  def initialize(text)
    @tree = Ripper.sexp(text)
    @lex = Ripper.lex(text)
    @lined_string = LinedString.new(text)
  end

  # @return [Array<Array<String>>] Returns the start and end coordinates of
  #   each call to the provided method name.
  def calls_to(method_name)
    calls = self.class.calls_to(method_name, @tree).map { |subtree| Ripper.hashify(subtree) }
    calls.map do |subtree|
      self.class.get_coordinates(subtree).map { |c| @lined_string.convert(c) }
    end
  end

  # @return [Array<Array<String>>] Returns the string and comments of each
  #   call to nt.
  def args_to(method_name)
    calls = self.class.calls_to(method_name, @tree).map { |subtree| Ripper.hashify(subtree) }
    calls.map do |subtree|
      args = get_args(subtree)
      args[0..1].map { |arg_tree| arg_tree[:string_literal][:string_content][:@tstring_content][0] }
    end
  end

  private

  def self.calls_to(name, tree)
    calls = []
    if Enumerable === tree
      tree.each do |subtree|
        if Symbol === subtree
          next
        elsif Array === subtree && is_call_to(name, subtree)
          calls.push(subtree)
        else
          calls += calls_to(name, subtree)
        end
      end
    end
    calls
  end

  def self.get_args(subtree)
    if Hash === subtree
      if sub = (subtree[:command] || subtree[:command_call])
        sub[:args_add_block]
      elsif subtree[:method_add_arg] && subtree[:method_add_arg][:arg_paren]
        subtree[:method_add_arg][:arg_paren][:args_add_block]
      end
    elsif Array === subtree
      raise NotImplementedError
    end
  end

  # @return [Array<Array<Integer>>] The coordinates of the first and last
  #   tokens in the subtree passed
  def self.get_coordinates(subtree)
    coord = [nil, nil]
    if Hash === subtree
      subtree.values.each do |val|
        c = get_coordinates(val)
        coord[0] ||= c[0]
        coord[1] = c[1] if c[1].present?
      end
    elsif Array === subtree && subtree.length == 2 && subtree.all? { |v| Integer === v }
      coord[0] ||= subtree
      coord[1] = subtree
    elsif Array === subtree
      subtree.each do |v|
        c = get_coordinates(v)
        coord[0] ||= c[0]
        coord[1] = c[1] if c[1].present?
      end
    end
    coord
  end

  def self.is_call_to(name, subtree)
    (recognizer = method_call_recognizers[subtree[0]]) &&
      recognizer.call(name, subtree)
  end

  def self.method_call_recognizers
    {
      :command => proc { |name, subtree|
        if Array === subtree
          subtree[1][1] == name
        elsif Hash === subtree
          subtree[:command][:@ident][0] == name
        end
      },
      :command_call => proc { |name, subtree|
        if Array === subtree
          subtree[3][1] == name
        elsif Hash === subtree
          subtree[:command][3][:@ident][0] == name
        end
      },
      :method_add_arg => proc { |name, subtree|
        if Array === subtree
          begin
            subtree[1][1][1] == name || # nt(something)
              subtree[1][3][1] == name  # NaturalTranslation.nt(something)
          rescue
            false
          end
        elsif Hash === subtree
          begin
            subtree[:method_add_arg][:fcall][:@ident][0] == name ||  # nt(something)
              subtree[:method_add_arg][:call][3][:@ident][0] == name # NaturalTranslation.nt(something)
          rescue
            false
          end
        end
      },
    }
  end
end

# Add some useful Rails functionality
class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
  def present?
    !blank?
  end
end

class Ripper

  # Convert the nested Array results of Ripper to nested Hashes and Arrays
  # @param [Array<Array, ?>] The array-tree to convert to a hash-tree
  def self.hashify(subtree)
    if subtree.blank?
      subtree
    elsif Symbol === subtree[0]
      val = subtree[1..subtree.length].map { |sub| hashify(sub) }.reduce { |memo, obj|
        if Hash === memo && Hash === obj # Recursive case
          memo.merge(obj)
        elsif Array === memo # Base case extended
          memo.push(obj)
        else # Base case
          [memo, obj]
        end
      }
      { subtree[0] => val }
    elsif Array === subtree
      subtree.map { |obj| hashify(obj) }
    else
      subtree
    end
  end
end
