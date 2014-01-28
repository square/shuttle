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

require 'open-uri'
require 'locale'

namespace :locales do
  task :import do
    SIGN_LANGUAGES = %w( ils sfb sgn ) # + anything with "Sign Language" in the description

    records  = Array.new
    record   = nil
    last_key = nil

    open("http://www.iana.org/assignments/language-subtag-registry").each_line do |line|
      line = line.chomp
      if record
        if line =~ /^([A-Za-z0-9\-]+): (.+)$/
          record[$1] << $2
          last_key = $1
        elsif line.starts_with?('  ')
          if last_key
            record[last_key].last << " #{line.lstrip}"
          else
            puts "WARNING: ignoring append line with no prior key: #{line}"
          end
        elsif line == '%%'
          records << record
          record = Hash.new { |h, k| h[k] = Array.new }
        else
          puts "WARNING: ignoring unparseable line: #{line}"
        end
      else
        if line == '%%'
          record = Hash.new { |h, k| h[k] = Array.new }
        else
          puts "WARNING: ignoring out-of-record line: #{line}"
        end
      end
    end

    locales = Hash.new
    extlangs  = Hash.new { |h, k| h[k] = Hash.new }
    regions   = Hash.new
    variants  = Hash.new
    scripts   = Hash.new

    records.each do |record|
      next if record['Deprecated'].present?
      case record['Type'].first
        when 'language'
          next if record['Description'].first.include?('Sign Language') || SIGN_LANGUAGES.include?(record['Subtag'].first)
          locales[record['Subtag'].first] = record['Description'].first
        when 'extlang'
          next if record['Prefix'].first == 'sgn' # sign language
          extlangs[record['Prefix'].first][record['Subtag'].first] = record['Description'].first
        when 'region'
          regions[record['Subtag'].first] = record['Description'].first
        when 'script'
          scripts[record['Subtag'].first] = record['Description'].first
        when 'variant'
          prefixes = record['Prefix'].map { |prefix| Locale.from_rfc5646(prefix) }
          prefixes.each do |prefix|
            variants[prefix.iso639] ||= Hash.new
            hsh                     = variants[prefix.iso639]
            prefix.variants.each do |var|
              hsh[var] ||= Hash.new
              hsh      = hsh[var]
            end
            hsh[record['Subtag'].first]          ||= Hash.new
            hsh[record['Subtag'].first]['_END_'] = record['Description'].first
          end
      end
    end

    hsh = {
        'en' => {
            'locale' => {
                'format'   => {
                    'scripted'                      => "%{locale} (%{script} orthography)",
                    'regional'                      => "%{locale} (as spoken in %{region})",
                    'dialectical'                   => "%{locale} (%{dialect})",
                    'scripted_regional'             => "%{locale} (as spoken in %{region}, %{script} orthography)",
                    'scripted_dialectical'          => "%{locale} (%{dialect, %{script} orthography)",
                    'regional_dialectical'          => "%{locale} (%{dialect} as spoken in %{region})",
                    'scripted_regional_dialectical' => "%{locale} (%{dialect} as spoken in %{region}, %{script} orthography)"
                },
                'name'     => locales,
                'extended' => extlangs,
                'region'   => regions,
                'variant'  => variants,
                'script'   => scripts
            }
        }
    }

    File.open(Rails.root.join('config', 'locales', 'locales.en.yml'), 'w:UTF-8') do |f|
      f.puts hsh.to_yaml
    end
  end
end

