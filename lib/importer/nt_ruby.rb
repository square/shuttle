# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'ripper'

module Importer

  # Parses translatable strings from Ruby `.rb` files.
  #
  # WARNING: Only recognizes String literals (single- or double-quoted)
  # without any parentheses in their content
  #
  # TODO (wenley, tim) : Expand recognition beyond simple regex's

  class NtRuby < Base
    include NtBase

    def self.fencers() %w(RubyNt) end

    protected

    def import_file?(locale=nil)
      ::File.extname(file.path) == '.rb' # Import all .rb files?
    end

    def import_strings(receiver)
      nt_calls_in(file.contents).each do |message, comment|
        receiver.add_nt_string(key_for(message, comment), message, comment)
      end
    end

    private

    # @return [Array<Array<String>>] Returns the string and comments of each
    #   call to nt
    def nt_calls_in(source)
      tree = Ripper.sexp(source)
      calls = find_nt_in_parse_tree(tree).map { |subtree| puts "\n\n\nSubtrees:" ; pp subtree ; Ripper.hashify(subtree) }
      puts "\n\n\nCalls"
      pp calls
      calls.map do |subtree|
        args = get_args(subtree)
        args[0..1].map { |arg_tree| arg_tree[:string_literal][:string_content][:@tstring_content][0] }
      end
    end

    def get_args(subtree)
      if subtree[:command]
        subtree[:command][:args_add_block]
      elsif subtree[:method_add_arg] && subtree[:method_add_arg][:arg_paren]
        subtree[:method_add_arg][:arg_paren][:args_add_block]
      else
        nil
      end
    end

    def find_nt_in_parse_tree(tree)
      calls = []
      if Enumerable === tree
        tree.each do |subtree|
          pp subtree
          if Symbol === subtree
            puts "skipping...\n"
            next
          elsif Array === subtree &&
            [:command, :method_add_arg].include?(subtree[0]) &&
            subtree[1][1][1] == "nt"
            puts "appending...\n"
            calls.append(subtree)
          else
            puts "going deeper...\n"
            calls += find_nt_in_parse_tree(subtree)
          end
        end
      end
      calls
    end
  end
end

class Ripper
  # @private
  # Makes accessing subtree components much more readable
  #
  # @param [Array<Array<...>>] Nested arrays representing a syntax tree
  # @return [Hash<Hash, Array, ...>] Nested hashes representing the same tree
  def self.hashify(subtree)
    if ! subtree.present?
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
