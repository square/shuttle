# Copyright 2014 Square Inc.
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

require 'message_format'

module Fencer

  # Fences out Message Format tags using the intl-messageformat syntax.
  # See https://github.com/yahoo/intl-messageformat.
  # Also, see {Fencer}.

  module IntlMessageFormat
    extend self

    ESCAPED_BRACE = /\\([{}])/

    def fence(string)
      begin
        tokenize(::MessageFormat::Parser.parse(sanitize(string)))
      rescue
        {}
      end
    end

    def valid?(string)
      begin
        ::MessageFormat::Parser.parse(sanitize(string))
        true
      rescue
        false
      end
    end

    private

    def tokenize(segments, prefix: nil)
      # takes in the parsed structure from message_format and tokenize recursively all parameters in the string
      # {name} => {":name" => [-1..0]}
      # {num, plural , =0 {nothing!} one {one!}} => "{":number|plural|=0" => [-1..0], ":number|plural|one" => [-1..0]}"
      tokens = {}

      segments.each do |segment|
        next unless segment.instance_of?(Array)
        if segment.last.instance_of?(Hash)
          # select, plural, selectordinal
          *data, format = segment
          format.each do |k, v|
            key = generate_key(prefix, [*data, k])

            if v.length == 1 && v[0].instance_of?(String)
              # option is plain string
              tokens[key] = (tokens[key] || []).push(-1..0)
            else
              tokens.merge!(tokenize(v, prefix: key))
            end
          end
        else
          # simple argument, number, date, time type
          key = generate_key(prefix, segment)
          tokens[key] = (tokens[key] || []).push(-1..0)
        end
      end

      tokens
    end

    def generate_key(prefix, args)
      "#{prefix}:#{args.join('|')}"
    end

    def sanitize(string)
      # intl-message-format uses blackslash for escaping which is not consitent with ICU standard
      # replace blackslash with single quote so that message_format lib can parse it properly
      string.gsub(ESCAPED_BRACE, '\'\1\'')
    end
  end
end
