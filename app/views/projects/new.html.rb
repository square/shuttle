# encoding: utf-8

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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Projects
    class New < Views::Layouts::Application
      needs :project

      protected

      def body_content
        article(class: 'container') do
          page_header "Add Project"
          project_form
        end
      end

      def active_tab() 'admin' end

      private

      def project_form
        form_for @project, html: {class: 'form-horizontal'} do |f|
          fieldset do
            legend "General settings"

            div(class: 'control-group') do
              f.label :name, class: 'control-label'
              div(class: 'controls') do
                f.text_field :name
              end
            end

            div(class: 'control-group') do
              f.label :repository_url, class: 'control-label'
              div(class: 'controls') do
                f.text_field :repository_url
                p(class: 'help-block') do
                  text "This is the URL you use to check out the project in Git, "
                  strong "not"
                  text " the GitHub website URL."
                end
              end
            end

            div(class: 'control-group') do
              f.label :webhook_url, class: 'control-label'
              div(class: 'controls') do
                f.text_field :webhook_url
                p(class: 'help-block') do
                  text "This URL will be posted to when a commit is marked as 'ready'. HTTP Post body will contain "
                  tt 'commit_revision'
                  text ', '
                  tt 'project_name'
                  text ' and '
                  tt 'ready'
                  text " status."
                end
              end
            end
          end

          fieldset do
            legend "Locale settings"

            div(class: 'control-group') do
              f.label :base_rfc5646_locale, class: 'control-label'
              div(class: 'controls') do
                f.text_field :base_rfc5646_locale, class: 'locale-field'
                p "The locale that the original copy is written in.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :targeted_rfc5646_locales, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :targeted_rfc5646_locales, 'data-value' => @project.targeted_rfc5646_locales.to_json
                p class: 'help-block' do
                  text "A comma-delimited list of locales to target. Include "
                  text "any of " if PseudoTranslator.supported_rfc5646_locales.count > 1
                  PseudoTranslator.supported_rfc5646_locales.each { |l|
                    code l
                    text " "
                  }
                  text "to generate pseudo-translations."
                end
              end
            end
          end

          fieldset do
            legend "Importing settings"

            div(class: 'control-group') do
              f.label :skip_imports, class: 'control-label'
              div(class: 'controls') do
                # create a hidden field first so that if all checkboxes are unchecked, we at least get an empty array
                hidden_field_tag 'project[skip_imports][]', ''
                Importer::Base.implementations.each_with_index do |importer, index|
                  label_tag "project_skip_imports_#{index}", class: 'checkbox' do
                    check_box_tag "project[skip_imports][]", importer.ident, @project.skip_imports.include?(importer.ident), id: "project_skip_imports_#{index}"
                    text importer.human_name
                  end
                end
              end
            end

            div(class: 'control-group') do
              f.label :watched_branches, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :watched_branches, class: 'array-field', 'data-value' => @project.watched_branches.to_json
                p "New commits that appear on any of these branches will be automatically imported.", class: 'help-block'
              end
            end

            h4 "Key whitelisting and blacklisting"

            div(class: 'control-group') do
              f.label :key_inclusions, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :key_inclusions, class: 'array-field', 'data-value' => @project.key_inclusions.to_json
                p "List the keys that must be translated. If at least one inclusion is given, keys not matching will not be translated. UNIX-style globs are supported.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :key_exclusions, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :key_exclusions, class: 'array-field', 'data-value' => @project.key_exclusions.to_json
                p "List the keys you do not want to be translated. UNIX-style globs are supported.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :key_locale_inclusions, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :key_locale_inclusions, 'data-value' => @project.key_locale_inclusions.to_json
                p "List the keys that must be translated. If at least one inclusion is given, keys not matching will not be translated. UNIX-style globs are supported.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :key_locale_exclusions, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :key_locale_exclusions, 'data-value' => @project.key_locale_exclusions.to_json
                p "List the keys you do not want to be translated. UNIX-style globs are supported.", class: 'help-block'
              end
            end

            h4 "Path whitelisting and blacklisting"

            div(class: 'control-group') do
              f.label :only_paths, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :only_paths, class: 'array-field', 'data-value' => @project.only_paths.to_json
                p "List paths that importers will search for strings. Paths not in this list will not be searched.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :skip_paths, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :skip_paths, class: 'array-field', 'data-value' => @project.skip_paths.to_json
                p "List paths you do not want any importers to scan under for strings.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :only_importer_paths, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :only_importer_paths, 'data-value' => @project.only_importer_paths.to_json
              end
            end

            div(class: 'control-group') do
              f.label :skip_importer_paths, class: 'control-label'
              div(class: 'controls') do
                f.content_tag_field 'div', :skip_importer_paths, 'data-value' => @project.skip_importer_paths.to_json
              end
            end

            h4 "Precompilation and caching"

            div(class: 'control-group') do
              f.label :cache_localization, class: 'control-label'
              div(class: 'controls') do
                f.check_box :cache_localization
                localizers = Localizer::Base.implementations.map(&:human_name).sort.to_sentence
                p "The following localizers will be included in the tarball: #{localizers}.", class: 'help-block'
              end
            end

            div(class: 'control-group') do
              f.label :cache_manifest_formats, class: 'control-label'
              div(class: 'controls') do
                # create a hidden field first so that if all checkboxes are unchecked, we at least get an empty array
                hidden_field_tag 'project[cache_manifest_formats][]', ''
                # TODO (wenley, tim) : Once everything is on NT, remove
                # Exporter::Base
                (Exporter::Base.implementations.select(&:multilingual?) +
                 Exporter::NtBase.implementations.select(&:multilingual?)).each_with_index do |importer, index|
                  label_tag "project_cache_manifest_formats_#{index}", class: 'checkbox' do
                    check_box_tag "project[cache_manifest_formats][]", importer.request_format.to_s, @project.cache_manifest_formats.include?(importer.request_format.to_s), id: "project_cache_manifest_formats_#{index}"
                    text importer.human_name
                  end
                end
              end
            end
          end

          div(class: 'form-actions') do
            f.submit class: 'btn btn-primary'
            text ' '
            button 'Cancel', class: 'btn', href: administrators_url
          end
        end
      end
    end
  end
end
