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

require 'commit_traverser'

module Localizer

  # Mixin that allows iOS localizers to copy localizable assets _without_ any
  # translated content into the localized tarball. For example, if a project
  # contains two storyboards, one of which has a few translatable strings, and
  # the other of which does not, _both_ storyboards will be found in the (e.g.)
  # `de.lproj` directory even though only one requires translation.
  #
  # This module is included by both xib localizers and the storyboard localizer.

  module CopiesIosResourcesWithoutTranslations
    include CommitTraverser

    # @private
    def post_process(commit, receiver, *locales)
      return #TODO temporarily disabled because this is very slow
      ios_resources = all_ios_resources(commit)
      resources_to_copy = ios_resources.keys - translated_ios_resources(commit)
      resources_to_copy.each do |resource_path|
        contents = ios_resources[resource_path]
        locales.each do |locale|
          locale_path = resource_path.sub("#{commit.project.base_rfc5646_locale}.lproj", "#{locale.rfc5646}.lproj")
          receiver.add_file locale_path, contents, overwrite: false
        end
      end
    end

    private

    def all_ios_resources(commit)
      resources = {}
      traverse commit.commit! do |path, blob|
        resources[path.sub!(/^\//, '')] = blob.contents if copy_resource?(path, blob, commit.project)
      end
      return resources
    end

    def translated_ios_resources(commit)
      resources = []
      Localizer::Base.organize_translations(commit).each do |_, sources|
        resources.concat sources.keys
      end
      return resources
    end
  end
end
