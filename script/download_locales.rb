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

require 'open-uri'
require 'yaml'
require 'i18n'

I18n.load_path = Dir[File.dirname(__FILE__) + '/../config/locales/*.yml']
I18n.reload!

langs = open('http://www.iana.org/assignments/language-subtag-registry/').read.split(/\n/).map { |line| line.split(/\t/).map(&:strip) }

mappings = {}
langs.each do |(country, languages)|
  code = I18n.t('locale.region').key(country)
  unless code
    $stderr.puts "Skipping unknown country #{country}"
    next
  end
  
  languages = languages.split(/[,;]\s*/)
  languages.each do |l|
    l.gsub! /\s+\(.+\)$/, ''
    l.gsub! /\s+\d+(\.\d+)?%$/, ''
  end
  
  locale_code = languages.map do |locale|
    I18n.t('locale.name').key(locale) || locale
  end.first
  
  mappings[locale_code.to_s] = code.to_s
end

puts mappings.to_yaml
