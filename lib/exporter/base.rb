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

# Container module for {Exporter::Base} and its subclasses.

module Exporter

  # @abstract
  #
  # Abstract superclass for all exporters. Exporters take a database of
  # Translations as stored in this program, and export it for use with an
  # external translation tool (such as TRADOS), or for reintegration back into
  # a project in a format suitable for use with a particular i18n library.
  #
  # Subclasses should implement at a minimum {#export}.

  class Base
    # @return [Array<Class>] All known implementations of the base class.
    #   Automatically updated.
    class_attribute :implementations
    self.implementations = []

    # @private
    def self.inherited(subclass)
      self.implementations << subclass
    end

    # Prepares an exporter for use with a Commit.
    #
    # @param [Commit] commit A Commit whose Translations will be exported.

    def initialize(commit)
      @commit = commit
    end

    # @abstract
    #
    # @overload export(io, locale, ...)
    #   Exports the Translations to an output stream.
    #   @param [IO] io The output stream to write to.
    #   @param [Locale] locale A locale to export.

    def export(io, *locales)
      raise NotImplementedError
    end

    # @return [String] The file extension of this exporter's output format.

    def self.file_extension
      other_mime_type = MIME::Types[request_mime.to_s].first
      other_mime_type.extensions.first
    end

    # @abstract
    #
    # @return [Symbol] The identifier of the MIME type format of the HTTP
    #   request that would invoke this exporter.

    def self.request_format
      raise NotImplementedError
    end

    # @return [Mime::Type, nil] The MIME type format of the HTTP request that
    #   would invoke this exporter. Note that this returns a `Mime::Type`, not a
    #   `MIME::Type` (yes, they're different).

    def self.request_mime
      Mime.const_get request_format.to_s.upcase
    end

    # @return [String] The MIME type of this exporter's output format.

    def self.mime_type
      mime = request_mime.to_s
      mime << "; charset=#{character_encoding.downcase}" unless character_encoding == 'UTF-8'
      mime
    end

    # @return [String] The human-readable description of this exporter's file
    #   format.
    def self.human_name() I18n.t "exporter.#{ident}.name" end

    # @return [String] The unique identifier of this exporter, used in the code.
    def self.ident() to_s.demodulize.underscore end

    # @return [String] The character encoding the output is in.
    def self.character_encoding() 'UTF-8' end

    # @return [true, false] Whether this exporter is capable of exporting
    #   multiple locales in a single file (default true).
    def self.multilingual?() true end

    # Locates an exporter subclass from its unique identifier.
    #
    # @param [String] ident An identifier.
    # @return [Class, nil] an exporter subclass.

    def self.find_by_ident(ident)
      "Exporter::#{ident.camelize}".constantize
    rescue NameError
      nil
    end

    # Locates an exporter that can handle a given request format.
    #
    # @param [String] format A request format, such as "yaml".
    # @return [Class, nil] The exporter that handles that format.

    def self.find_by_format(format)
      implementations.detect { |exp| exp.request_format == format.to_sym }
    end

    # @abstract
    #
    # Tests the validity of an exported file. This can be as simple is ensuring
    # that the file is not empty, or can involve running lint tests or syntax
    # checks.
    #
    # The default implementation ensures the file is not empty.
    #
    # @param [String] contents The contents of an exported file.
    # @return [true, false] Whether or not the contents are syntactically valid.

    def self.valid?(contents)
      !contents.blank?
    end

    protected

    # This method builds a hash mapping keys to their translated values. The
    # hash contains subhashes built by bisecting keys on the period character.
    # This utility function is useful for exporting to YAML, for example.
    #
    # @param [Locale] locale A locale to use for hash values.
    # @param [Array<Locale>] deduplicate An array of locales to de-duplicate
    #   translations from. Translations that are identical to any translation
    #   in one of these locales will not be included.
    # @return [Hash<String, (Hash, String)>] A nested hash mapping localization
    #   keys to their translated values.

    def translation_hash(locale, deduplicate=[])
      hsh = Hash.new

      translations = Translation.in_commit(@commit).includes(:key).where(rfc5646_locale: locale.rfc5646, translated: true)

      # batch preload possible duplicate translations
      possible_duplicates = Hash.new { |h,k| h[k] = Array.new }
      translations.in_groups_of(100, false) do |group|
        Translation.where(key_id: group.map(&:key_id), rfc5646_locale: deduplicate.map(&:rfc5646)).includes(:key).each do |dup|
          possible_duplicates[dup.key.key] << dup.copy
        end
      end

      # de-duplicate translations
      translations.reject! do |translation|
        possible_duplicates[translation.key.key].include?(translation.copy)
      end if deduplicate.present?

      translations.sort_by! { |t| t.key.key }

      translations.each do |translation|
        begin
          this_object = hsh
          key_parts   = translation.key.key.split('.')
          last = key_parts.pop

          until key_parts.empty?
            # part will either be the key index of a hash or the integer index
            # of an array we created on the previous iteration
            part = key_parts.shift
            # if the key part looks like "foo[1][2][3]", grab foo into $1 and
            # [1][2][3] into $2
            if part.kind_of?(String) && part =~ /^(.+?)((?:\[(\d+)\])+)$/
              # build the first array under the key name ("foo")
              this_object = this_object[$1] ||= Array.new
              # build an index path ([1, 2, 3]) so that we can build nested arrays
              index_path = part.scan(/\[(\d+)\]/).flatten.map(&:to_i)
              # the deepest index doesn't have an array under it, so handle that
              # separately
              deepest_index = index_path.pop
              # but for all but the deepest index, we can add nested arrays
              index_path.each do |index|
                this_object = this_object[index] ||= Array.new
              end
              # stick the deepest index back into the key_parts list. next time
              # around we'll handle it like any other key
              key_parts.unshift deepest_index
            else
              this_object = this_object[part] ||= Hash.new
            end
          end

          # if the last key looks like "foo[1][2][3]", we need to build the
          # trailing arrays. see the similar block above for more information
          if last =~ /^(.+?)((?:\[(\d+)\])+)$/
            this_object = this_object[$1] ||= Array.new
            index_path = $2.scan(/\[(\d+)\]/).flatten.map(&:to_i)
            deepest_index = index_path.pop
            index_path.each do |index|
              this_object = this_object[index] ||= Array.new
            end
            # like with the above block, we handle the last nested array as if
            # it were a normal key
            last = deepest_index
          end
          # last is now either the key index of a hash (previous if didn't run)
          # or an array index (previous if did run)
          this_object[last] = translation.copy
        rescue => err
          Squash::Ruby.notify err, translation_id: translation.id
          raise if Rails.env.test?
        end
      end

      return hsh
    end
  end

  class NoLocaleProvidedError < StandardError; end
end

Dir.glob(Rails.root.join('lib', 'exporter', '*')).each { |f| require f }
