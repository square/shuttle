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

require 'multifile'

# Container module for {Localizer::Base} and its subclasses.

module Localizer

  # @abstract
  #
  # A variation on an {Exporter} that duplicates an original file and
  # substitutes translated copy for original copy. Whereas an exporter creates
  # a new file containing only localized content, a localizer creates a
  # localized copy of a file in the project.
  #
  # Subclasses should at a minimum implement {#localize}.

  class Base
    extend ::Multifile

    # @return [Array<Class>] All known implementations of the base class.
    #   Automatically updated.
    class_attribute :implementations
    self.implementations = []

    # @private
    def self.inherited(subclass)
      self.implementations << subclass
    end

    # @overload localize(commit, locale, ...)
    #   Localizes the localizable files in a Commit. Returns a String containing
    #   a gzipped tarball, extractable into the project root, with the localized
    #   files.
    #   @param [Commit] commit A Commit whose files will be localized.
    #   @param [Locale] locale A locale to localize to.
    #   @return [String] The contents of a gzipped tarball with the localized
    #     files, extractable to the project root.

    def self.localize(commit, *locales)
      locales = commit.project.required_locales if locales.empty?
      organized_translations = organize_translations(commit, *locales)

      build_archive do |receiver|
        organized_translations.each do |localizer, translations_by_source|
          klass              = find_by_ident(localizer)

          translations_by_source.each do |source, translations_by_locale|
            file_contents =
                  commit.project.repo.object("#{commit.revision}^{tree}:#{source}").try!(:contents)
            next unless file_contents
            input_file = Localizer::File.new(source, file_contents)

            translations_by_locale.each do |locale, translations|
              output_file        = Localizer::File.new
              localizer_instance = klass.new(commit.project, translations)

              Rails.logger.tagged(klass.to_s) do
                localizer_instance.localize input_file, output_file, Locale.from_rfc5646(locale)
              end
              next unless output_file.path && output_file.content
              receiver.add_file output_file.path, output_file.content
            end
          end

          klass.new(commit.project, []).post_process commit, receiver, *locales
        end
      end
    end

    # @overload post_process(commit, receiver, locale, ...)
    #   Override this method to do additional post-processing of the localized
    #   archive before the file is closed and sent to the client. Use this,
    #   e.g., to add additional files to the archive.
    #   @param [Commit] commit The commit being localized.
    #   @param [Multifile::Receiver] A proxy object allowing you to add files to
    #     the archive.
    #   @param [Locale] locale A locale being included in the archive.

    def post_process(commit, receiver, *locales)
    end

    # Prepares a localizer for use with a Commit.
    #
    # @param [Project] project The Project containing the file being localized.
    # @param [Translation] translations The Translations to be used when
    #   localizing this file. They should have all been imported from the same
    #   file.

    def initialize(project, translations)
      @project      = project
      @translations = translations
    end

    # @abstract
    #
    # @param [Project] project A Project.
    # @param [String] path The full path, relative to the project root, of a
    #   file.
    # @return [true, false] Whether the file is appropriate for this localizer.
    def self.localizable?(project, path) false end

    # @abstract
    #
    # Generates a localized copy of a file.
    #
    # @param [Localizer::File] input_file The file being localized.
    # @param [Localizer::File] output_file An empty Localizer::File to contain
    #   the localized data. You should set the `path` and `content` attributes.
    # @param [Locale] locale The desired locale of the output file.

    def localize(input_file, output_file, locale)
      raise NotImplementedError
    end

    # @return [String] The human-readable description of this exporter's file
    #   format.
    def self.human_name() I18n.t "localizer.#{ident}.name" end

    # @return [String] The unique identifier of this exporter, used in the code.
    def self.ident() to_s.demodulize.underscore end

    # Locates an exporter subclass from its unique identifier.
    #
    # @param [String] ident An identifier.
    # @return [Class, nil] an exporter subclass.

    def self.find_by_ident(ident)
      "Localizer::#{ident.camelize}".constantize
    rescue NameError
      nil
    end

    # @private
    def self.organize_translations(commit, *locales)
      #TODO cache somehow

      # by localizer, then by source, then by locale
      organized_translations = Hash.new { |h, k|
        h[k] = Hash.new { |h2, k2|
          h2[k2] = Hash.new { |h3, k3|
            h3[k3] = []
          }
        }
      }

      Translation.in_commit(commit).includes(:key).not_base.
          where(approved: true, rfc5646_locale: locales.map(&:rfc5646)).each do |translation|
        next unless translation.key.source
        source    = translation.key.source.sub(/^\//, '')
        localizer = implementations.detect { |localizer| localizer.localizable?(commit.project, translation.key) }
        next unless localizer
        organized_translations[localizer.ident][source][translation.rfc5646_locale] << translation
      end

      organized_translations
    end
  end

  # Represents a file in the project directory.
  File = Struct.new(:path, :content)
end
