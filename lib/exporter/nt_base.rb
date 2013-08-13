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

module Exporter

  module NtBase

    @@implementations = []
    def NtBase.included(klass)
      @@implementations << klass
    end
    def NtBase.implementations
      @@implementations
    end

    def nt_hash(*locales)
      hsh = Hash.new
      keys = @commit.keys.includes(:translations)
      keys.each do |key|
        translation_set = {
          "string"  => key.source_copy,
          "comment" => key.comment
        }
        locales = locales.dup
        locales.delete(key.translations.first.source_locale) # Don't want to double include default
        translations = key.translations.select { |t| locales.include?(t.locale) }
        translation_set["translations"] = translations.map { |t|
          {
            "locale" => t.locale.rfc5646,
            "string" => t.copy,
            "rules"  => t.rules
          }.delete_if { |k,v| v.nil? }
        }
        hsh[key.key] = translation_set.delete_if { |k,v| v.nil? }
      end
      hsh
    end
  end
end
