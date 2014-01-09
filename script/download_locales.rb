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
require 'yaml'
require 'i18n'

class SubtagRegistryParser < Parslet::Parser
  rule(:key) { match('[A-Za-z0-9\\-]').repeat(1).as(:key) }
  rule(:value) { (match('[^\n\r]') | str("\n  ")).repeat(1).as(:value) }
  rule(:pair) { key >> str(': ') >> value }
  rule(:entry) { str("%%\n") >> (pair >> str("\n")).repeat(1).as(:entry) }
  rule(:header) { (pair >> str("\n")).repeat }
  rule(:file) { header >> entry.repeat.as(:file) }

  root :file
end

class SubtagRegistryTransform < Parslet::Transform
  rule(key: subtree(:x)) { x == [] ? '' : x.to_s }
  rule(value: subtree(:x)) { x == [] ? '' : x.to_s.gsub("\n  ", ' ') }
  rule(entry: subtree(:x)) do
    x.inject({}) do |hsh, subtree|
      hsh[subtree[:key].to_s] ||= Array.new
      hsh[subtree[:key].to_s] << subtree[:value].to_s.gsub("\n  ", ' ')
      hsh
    end
  end
  rule(file: subtree(:x)) { Array.wrap(x) }
end

I18n.load_path = Dir[File.dirname(__FILE__) + '/../config/locales/*.yml']
I18n.reload!

data = open('http://www.iana.org/assignments/language-subtag-registry/').read
ast  = SubtagRegistryParser.new.parse(data)
begin
  registry = SubtagRegistryTransform.new.apply(ast)
rescue Parslet::ParseFailed => error
  puts error.cause.ascii_tree
  exit 1
end

mappings = {
    'en' => {
        'locale' => {
            'format'   => {
                'scripted'                      => '%{language} (%{script} orthography)',
                'regional'                      => '%{language} (as spoken in %{region})',
                'dialectical'                   => '%{language} (%{dialect})',
                'scripted_regional'             => '%{language} (as spoken in %{region}, %{script} orthography)',
                'scripted_dialectical'          => '%{language} (%{dialect, %{script} orthography)',
                'regional_dialectical'          => '%{language} (%{dialect} as spoken in %{region})',
                'scripted_regional_dialectical' => '%{language} (%{dialect} as spoken in %{region}, %{script} orthography)'
            },
            'name'     => {},
            'extended' => {},
            'region'   => {},
            'variant'  => {},
            'script'   => {}
        }
    }
}

registry.last.each do |entry|
  case entry['Type'].try!(:first)
    when 'language'
      if (existing = mappings['en']['locale']['name'][entry['Subtag'].first])
        raise "Language #{existing} would be overwritten by #{entry.inspect}"
      end
      mappings['en']['locale']['name'][entry['Subtag'].first] = entry['Description'].first
    when 'extlang'
      mappings['en']['locale']['extended'][entry['Prefix'].first] ||= {}
      if (existing = mappings['en']['locale']['extended'][entry['Prefix'].first][entry['Subtag'].first])
        raise "Language #{existing} would be overwritten by #{entry.inspect}"
      end
      mappings['en']['locale']['extended'][entry['Prefix'].first][entry['Subtag'].first] = entry['Description'].first
    when 'script'
      if (existing = mappings['en']['locale']['script'][entry['Subtag'].first])
        raise "Script #{existing} would be overwritten by #{entry.inspect}"
      end
      mappings['en']['locale']['script'][entry['Subtag'].first] = entry['Description'].first
    when 'region'
      if (existing = mappings['en']['locale']['region'][entry['Subtag'].first])
        raise "Region #{existing} would be overwritten by #{entry.inspect}"
      end
      mappings['en']['locale']['region'][entry['Subtag'].first] = entry['Description'].first
    when 'variant'
      if entry['Prefix'].blank?
        puts "Skipping universal subtag #{entry.inspect}"
        next
      end
      entry['Prefix'].each do |prefix|
        path = prefix.split('-') << entry['Subtag'].first
        hsh  = mappings['en']['locale']['variant']
        path.each { |item| hsh = (hsh[item] ||= {}) }

        if (existing = hsh['_END_'])
          raise "Variant #{existing} would be overwritten by #{entry.inspect}"
        end
        hsh['_END_'] = entry['Description'].first
      end
  end
end

File.open(Rails.root.join('config', 'locales', 'locales.en.yml'), 'w') { |f| f.puts mappings.to_yaml }
