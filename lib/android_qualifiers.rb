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

# Cpde for dealing with Android's concept of "qualifiers," metadata associated
# with a string that indicates on what devices that string applies.

module AndroidQualifiers
  extend self

  # Android resource qualifiers.
  QUALIFIERS = [
      ['mcc', /^mcc\d{3}$/],
      ['mnc', /^mnc\d{3}$/],
      ['language', /^[a-zA-Z]{2}$/],
      ['region', /^r[a-zA-Z]{2}$/],
      ['layout_direction', %w(ldrtl ldltr)],
      ['smallest_width', /^sw\d+dp$/],
      ['available_width', /^w\d+dp$/],
      ['available_height', /^h\d+dp$/],
      ['screen_size', %w(small normal large xlarge)],
      ['screen_aspect', %w(long notlong)],
      ['screen_orientation', %w(port land)],
      ['ui_mode', %w(car desk television appliance)],
      ['night_mode', %w(night nonight)],
      ['screen_pixel_density', %w(ldpi mdpi hdpi xhdpi nodpi tvdpi)],
      ['touchscreen_type', %w(notouch finger)],
      ['keyboard_availability', %w(keysexposed keyshidden keyssoft)],
      ['primary_text_input_method', %w(nokeys qwerty 12key)],
      ['navigation_key_availability', %w(navexposed navhidden)],
      ['primary_nontouch_navigation_method', %w(nonav dpad trackball wheel)],
      ['platform_version', /^v\d+$/]
  ]

  # Convert a directory name into a hash of qualifier values.
  #
  # @param [String] dirname The name of the directory under which the strings
  #   appeared.
  # @return [Hash<String, String>] A hash mapping keys found in {QUALIFIERS} to
  #   their values.

  def parse_qualifiers(dirname)
    qualifier_names = dirname.split('-')
    qualifiers      = {}

    QUALIFIERS.reverse.each do |(qualifier, matcher)|
      matches = case matcher
                  when Regexp then
                    qualifier_names.last =~ matcher
                  when Array then
                    matcher.include?(qualifier_names.last)
                  when String then
                    matcher == qualifier_names.last
                end

      if matches
        qualifiers[qualifier] = qualifier_names.pop
      end
    end

    return qualifier_names.join('-'), qualifiers
  end

  # Convert a hash of qualifier names and values into a directory name.
  #
  # @param [String] name The base portion of the directory name.
  # @param [Hash<String, String>] qualifiers Qualifier names and values, as
  #   would be returned by {#parse_qualifiers}.
  # @return [String] The name of the directory strings with those qualifiers
  #   should appear under.

  def serialize_qualifiers(name, qualifiers)
    ([name] + QUALIFIERS.map(&:first).map { |q| qualifiers[q] }.compact).join('-')
  end
end
