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

# Ruby re-implementation of the iOS genstrings utility, which searches for
# calls to `NSLocalizedString` and similar routines and extracts them as
# localizable content.
#
# The Genstrings class does not generate Strings files, however; instead, it
# yields detected key-value pairs for further processing.
#
# C and Objective-C
# -----------------
#
# Source lines containing text of the form `NSLocalizedString("key", comment)`
# or `CFCopyLocalizedString("key", comment)` will yield an appropriate key-value
# pair.
#
# Source lines containing `NSLocalizedStringFromTable("key", Table, comment)` or
# `CFCopyLocalizedStringFromTable("key", Table, comment)` will yield an
# appropriate key-value pair if the `:skip_table` option does not match. The
# same is true for
# `NSLocalizedStringFromTableInBundle("key", Table, bundle, comment)` and
# `CFCopyLocalizedStringFromTableInBundle("key", Table, bundle, comment)`.
#
# Source lines with
# `NSLocalizedStringWithDefaultValue("key", Table, bundle, "value", comment)` or
# `CFCopyLocalizedStringWithDefaultValue("key", Table, bundle, "value", comment)`
# will yield an appropriate-key value pair if the `:skip_table` option does not
# match.
#
# Format Strings and Positional Parameters
# ----------------------------------------
#
# Keys and values of string file entries can include formatting characters.
# For value strings with multiple formatting arguments, positional parameters
# are generated.  These allow the order of arguments to be changed as needed by
# each localization (e.g. "File %1$@ contains %2$d bytes." could become
# "%2$d bytes are contained in file %1$@." in another localization).
#
# Encoding
# --------
#
# The String instances passed to Genstrings are assumed to be correctly encoded
# already.
#
# Embedded non-ASCII characters in strings, as well as non-ASCII characters
# specified by the escape sequences `\uxxxx` and `\Uxxxxxxxx`, are read
# automatically by genstrings.  Genstrings-specific escape sequence are also
# supported.

class Genstrings
  include ::CStrings

  # @return [Hash] options Genstrings options.
  attr_reader :options

  # The default routine prefixes to use if no custom one is provided.
  DEFAULT_PREFIXES  = %w(NSLocalizedString CFCopyLocalizedString)

  # Routine suffixes mapped to the method signature.
  SUFFIX_SIGNATURES = {
      ''                  => [:key, :comment],
      'FromTable'         => [:key, :table, :comment],
      'FromTableInBundle' => [:key, :table, :bundle, :comment],
      'WithDefaultValue'  => [:key, :table, :bundle, :value, :comment]
  }

  # @private
  NSSTRING_REGEX = "@\"(?:[^\"\\\\]|\\\\.)*\""
  # @private
  CFSTRING_REGEX = "CFSTR\\s*\\(\\s*\"(?:[^\"\\\\]|\\\\.)*\"\\s*\\)"

  # Initializes a new Genstrings instance with the given options.
  #
  # @param [Hash] options Additional options.
  # @option options [String] :routine ("NSLocalizedString") Substitutes a
  #   routine for NSLocalizedString.  For example, "MyLocalString" will catch
  #   calls to `MyLocalString` and `MyLocalStringFromTable`.
  # @option options [String] :skip_table Skips over strings for a given table.
  # @option options [true, false] :positional_parameters (true) When `false`,
  #   turns off generation of positional parameters.

  def initialize(options={})
    @options = options.reverse_merge(
        routine:               DEFAULT_PREFIXES,
        positional_parameters: true
    )
  end

  # Searches a code file for calls to string localization method calls. Yields
  # each located method call with additional information.
  #
  # @param [String] code The code to scan.
  # @yield [params] Code to execute for each located string.
  # @yieldparam [Hash<Symbol, String>] params A hash containing information
  #   about the parameters of the method call. Hash keys can be `:key`,
  #   `:value`, `:comment`, and `:table`.

  def search(code)
    Array.wrap(options[:routine]).each do |prefix|
      SUFFIX_SIGNATURES.each do |suffix, signature|
        routine   = prefix + suffix
        regexp    = "#{Regexp.escape routine}\\s*\\(\\s*"
        param_rxs = signature.map do |parameter|
          case parameter
            when :key
              "(#{NSSTRING_REGEX}|#{CFSTRING_REGEX}|nil|NULL|0L?)"
            when :value
              "(#{NSSTRING_REGEX}|#{CFSTRING_REGEX}|nil|NULL|0L?)"
            when :comment
              "(#{NSSTRING_REGEX}|#{CFSTRING_REGEX}|nil|NULL|0L?)"
            when :table
              "(#{NSSTRING_REGEX}|#{CFSTRING_REGEX}|nil|NULL|0L?)"
            else
              '(.+?)'
          end
        end
        regexp << param_rxs.join("\\s*,\\s*")
        regexp << "\\s*\\)"

        code.scan(Regexp.compile(regexp, Regexp::MULTILINE)).each do |params|
          params.map! do |param|
            if %w(nil null NULL 0 0L).include?(param)
              nil
            elsif param =~ /^@"(.*)"$/m
              unescape $1
            elsif param =~ /^CFSTR\s*\(\s*"(.*)"\s*\)$/m
              unescape $1
            else
              nil # could be e.g. a variable name, so let's ignore it
            end
          end

          params_hash = signature.zip(params).inject({}) do |hsh, (name, value)|
            hsh[name] = value if name && value
            hsh
          end

          next if params_hash[:key].blank?
          next if options[:skip_table] && params_hash[:table] == options[:skip_table]

          if options[:positional_parameters]
            params_hash[:value] = add_positional_parameters(params_hash[:value] || params_hash[:key])
          end

          yield params_hash
        end
      end
    end
  end

  private

  def add_positional_parameters(string)
    tokenized = ''
    counter    = 1

    PrintfTokenizer.tokenize(string) do |kind, value|
      case kind
        when :substring
          tokenized << value
        when :token
          value.match /^%(\d+\$)?(.+)$/
          if $1 # has position already; replace it
            tokenized << '%' << counter.to_s << $2
          else # add position
            tokenized << '%' << counter.to_s << '$' << $2
          end
          counter += 1
      end
    end

    return tokenized
  end
end
