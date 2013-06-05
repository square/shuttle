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

require 'find'

# Container module for {Importer::Base} and its subclasses.

module Importer

  # @abstract
  #
  # Abstract superclass for all importers. Importers pull localizable strings
  # from a Project's source code and convert them to {Translation} records.
  # Subclasses should implement at a minimum {#import_file?} and
  # {#import_strings}.
  #
  # Importers perform two different kinds of imports: **base imports** do not
  # have an associated locale, and import strings in the project's base locale.
  # New keys are created as necessary. The translations are marked as approved
  # automatically.
  #
  # **Translation imports** are specific to a locale, and import existing
  # translations in that locale. New keys are not created automatically, and
  # must have been created by a prior base import. Translations are marked as
  # approved automatically.

  class Base
    # Byte-order marks for different encodings.
    BOMS = {
        'UTF-8'    => [[0xEF, 0xBB, 0xBF]],
        'UTF-16BE' => [[0xFE, 0xFF]],
        'UTF-16LE' => [[0xFF, 0xFE]],
        'UTF-32BE' => [[0x00, 0x00, 0xFE, 0xFF]],
        'UTF-32LE' => [[0xFF, 0xFE, 0x00, 0x00]],
        'UTF-7'    => [[0x2B, 0x2F, 0x76, 0x38], [0x2B, 0x2F, 0x76, 0x39], [0x2B, 0x2F, 0x76, 0x2B], [0x2B, 0x2F, 0x76, 0x2F], [0x2B, 0x2F, 0x76, 0x38, 0x2D]],
        'GB18030'  => [[0x84, 0x31, 0x95, 0x33]]
    }
    BOMS.default = []

    # @return [Array<Class>] All known implementations of the base class.
    #   Automatically updated.
    class_attribute :implementations
    self.implementations = []

    # @private
    def self.inherited(subclass)
      self.implementations << subclass
    end

    # @return [String] The human-readable description of this importer's file
    #   format.
    def self.human_name() I18n.t "importer.#{ident}.name" end

    # @return [String] The unique identifier of this importer, used in the code
    #   and database fields.
    def self.ident() to_s.demodulize.underscore end

    # Locates an importer subclass from its unique identifier.
    #
    # @param [String] ident An identifier.
    # @return [Class, nil] an importer subclass.

    def self.find_by_ident(ident)
      "Importer::#{ident.camelize}".constantize
    rescue NameError
      nil
    end

    # @return [Importer::Base::File] Data about the file being imported.
    attr_reader :file

    # Prepares an importer for use with a Blob.
    #
    # @param [Blob] blob A Blob whose strings will be imported.
    # @param [String] path The path to this blob in the commit currently being
    #   imported.
    # @param [Commit] commit If given, new Keys will be added to this Commit's
    #   `keys` association.

    def initialize(blob, path, commit=nil)
      @blob   = blob
      @commit = commit
      @file   = File.new(path, nil, nil)
    end

    # Scans the Blob for localizable strings, and creates or updates
    # corresponding Translation records.

    def import
      load_contents

      @keys = []
      Rails.logger.tagged("#{self.class.to_s} #{@blob.sha}") do
        process_blob_for_string_extraction
      end
      @commit.keys += @keys if @commit

      # cache the list of keys we know to be in this blob for later use
      Shuttle::Redis.set "keys_for_blob:#{@blob.id}", @keys.map(&:id).join(',')
    end

    # Scans the blob for localizable strings, assumes their values are of a
    # given locale, and creates unapproved Translations for those strings. This
    # will not work for localization frameworks that use the value of the string
    # as its key, since the value changes with each locale.

    def import_locale(locale)
      load_contents
      Rails.logger.tagged("#{self.class.to_s} #{@blob.sha}") do
        process_blob_for_translation_extraction locale
      end
    end

    # @abstract
    #
    # @return [Array<Module>] Returns the {Fencer} modules used to fence content
    #   in this format, if any.
    def self.fencers() [] end

    # @abstract
    #
    # Determines if the filename stored in `file.path` is one that would contain
    # localizable content.
    #
    # @param [String] locale The locale to assume the strings are in. By default
    #   it should assume the Project's base locale. If the file does not match
    #   the locale (e.g., the locale is en-US but the file is `strings.fr.yml`),
    #   this method should return `false`.
    # @return [true, false] Whether this file should be scanned for strings.
    def import_file?(locale=nil) raise NotImplementedError end

    # Returns whether this importer should not be used, based on the Project's
    # whitelisted/blacklisted file path settings and the implementation of the
    # {#import_file?} method.
    #
    # @param [Locale, nil] locale A locale to import, or `nil` if this is a base
    #   language import.
    # @return [true, false] Whether this importer should not be run.

    def skip?(locale)
      @blob.project.skip_path?(file.path, self.class) || !import_file?(locale)
    end

    # @abstract
    #
    # Given the contents of a file, locates translatable strings, and imports
    # them to Translation records using the `receiver`. Implementations of this
    # method should scan the file's contents for localizable strings, and then
    # pass those strings to the receiver by calling `add_string`.
    #
    # Importers that work with keys constructed of nested hash keys (such as
    # Ruby YAML importers and Ember importers) can use the {#extract_hash}
    # method as a convenience to convert those nested keys into period-delimited
    # keys.
    #
    # @param [Importer::Base::Receiver] receiver A proxy object that receives
    #   strings to import.
    #
    # @example Importing strings from a CSV file ("key,string")
    #   def import_strings(receiver)
    #     CSV.parse(file.contents) do |row|
    #       receiver.add_string row[0], row[1]
    #     end
    #   end
    def import_strings(receiver) raise NotImplementedError end

    # @return [String, Array<String>] The character encoding to assume files
    #   use. If multiple encodings are provided, they are each tried in order
    #   until one produces a valid encoding.
    def self.encoding() %w(UTF-8) end

    # Returns either the given locale or the Project's base locale if `nil` is
    # given.
    #
    # @param [Locale] locale A locale to use for a translation import.
    # @return [Locale] The given locale (translation import) or the base locale
    #   (string import).

    def locale_to_use(locale=nil)
      locale || @blob.project.base_locale
    end

    # @private
    def add_string(key, value, options={})
      #if @blob.project.skip_key?(key, @blob.project.base_locale)
      #  log_skip key, "skip_key? returned true for #{@blob.project.base_locale.inspect}"
      #  return
      #end

      key = @blob.project.keys.for_key(key).source_copy_matches(value).create_or_update!(
          options.reverse_merge(
              key:                      key,
              source_copy:              value,
              importer:                 self.class.to_s.demodulize,
              fencers:                  self.class.fencers,
              skip_readiness_hooks:     true
          ), as: :system
      )
      @keys << key unless @keys.include?(key)

      key.translations.in_locale(@blob.project.base_locale).create_or_update!({
              source_copy:              value,
              copy:                     value,
              approved:                 true,
              source_rfc5646_locale:    @blob.project.base_rfc5646_locale,
              rfc5646_locale:           @blob.project.base_rfc5646_locale,
              skip_readiness_hooks:     true,
              preserve_reviewed_status: true
          }, as: :system)

      # add additional pending translations if necessary
      key.add_pending_translations
    end

    # @private
    def add_translation(key, value, locale)
      raise "Can't do a translation import without a commit" unless @commit

      if @blob.project.skip_key?(key, locale)
        log_skip key, "skip_key? returned true for #{locale.inspect}"
        return
      end

      key = @commit.keys.for_key(key).first
      unless key
        log_skip key, "Couldn't find key"
        return
      end

      base = key.translations.base.first
      unless base
        log_skip key, "Couldn't find base translation"
        return
      end

      key.translations.in_locale(locale).create_or_update!({
              source_copy:              base.copy,
              copy:                     value,
              approved:                 true,
              source_rfc5646_locale:    base.rfc5646_locale,
              rfc5646_locale:           locale.rfc5646,
              skip_readiness_hooks:     true,
              preserve_reviewed_status: true,
          }, as: :system)
    end

    protected

    # Given a nested hash of keys, such as this JSON hash:
    #
    # ```` json
    # {
    #   "foo":{
    #     "bar": "content1",
    #     "baz": "content2"
    #   }
    # }
    # ````
    #
    # yields each element of the hash as a flattened, period-delimited key,
    # value pair. The hash above would yield the following values to the block:
    #
    # ```` ruby
    # "foo.bar", "content1"
    # "foo.baz", "content2"
    # ````
    #
    # This makes it easy to extract nested hash-type i18n formats, such as YAML
    # or Ember JS.
    #
    # @param [Hash<String, String>] hsh A hash of nested localizable strings.
    # @param [Array<String>] key The key so far at this point in the hash
    #   traversal. For a first-time invocation, it should be an empty string.
    # @yield [key, string] Localizable strings.
    # @yieldparam [String] key A key path within the hash, period-delimited.
    # @yieldparam [String] string A localizable content value.

    def extract_hash(hsh, key='', &block)
      hsh.each do |key_portion, value|
        unless key_portion.kind_of?(String) || key_portion.kind_of?(Symbol)
          log_skip key, "#{key} -> #{key_portion.inspect} (not a string)"
          next
        end

        new_key = if key.empty?
                    key_portion.to_s
                  else
                    key + '.' + key_portion.to_s
                  end
        extract_value value, new_key, &block
      end
    end

    private

    def load_contents
      if (contents = utf8_encode(@blob.blob.contents))
        @file.contents = contents.encode('UTF-8')
      else
        raise "Invalid #{self.class.encoding.to_s} encoding"
      end
    end

    # array indexes are stored in brackets
    def extract_array(ary, key, &block)
      ary.each_with_index do |value, index|
        new_key = key + "[#{index}]"
        extract_value value, new_key, &block
      end
    end

    # if we encounter a string, we simply yield it to the block
    def extract_string(str, key, &block)
      block.(key, str)
    end

    def extract_value(value, key, &block)
      case value
        when String, Symbol
          extract_string value.to_s, key, &block
        when Hash
          extract_hash value, key, &block
        when Array
          extract_array value, key, &block
        else
          log_skip key, "Value is a #{value.class.to_s}"
      end
    end

    def process_blob_for_string_extraction
      if processed_blob?
        keys = Shuttle::Redis.get("keys_for_blob:#{@blob.id}")
        if keys
          @keys = Key.where(id: keys.split(',').map(&:to_i))
          return
        end
      end

      file.locale = nil
      import_strings Receiver.new(self)
    end

    def process_blob_for_translation_extraction(locale)
      file.locale = locale
      import_strings Receiver.new(self, locale)
    end

    def utf8_encode(string)
      encodings = []

      # first we want to scan and see if there is a recognizable BOM at the
      # start of the file. if so, we try that encoding first.
      Array.wrap(self.class.encoding).each do |encoding|
        encodings << encoding if BOMS[encoding].any? { |bom| string.bytes.first(bom.size) == bom }
      end

      # now add all other encodings
      Array.wrap(self.class.encoding).each { |enc| encodings << enc unless encodings.include?(enc) }

      # try each encoding in order; first valid one wins
      encodings.each do |encoding|
        begin
          converted = nil

          # remove the BOM if present
          BOMS[encoding].each do |bom|
            if string.bytes.first(bom.size) == bom
              converted = string.byteslice((bom.size)..-1)
              break
            end
          end
          converted ||= string.dup

          # reinterpret the string in the encoding
          converted.force_encoding encoding

          # if it's valid, we're done
          next unless converted.valid_encoding?
          return converted.encode('UTF-8')
        rescue EncodingError
          next
        end
      end

      raise NoEncodingFound, "Couldn't find valid encoding among #{self.class.encoding.join(', ')}"
    end

    def processed_blob?
      processed = false
      Blob.transaction do
        unless (processed = @blob.importers.include?(self.class.to_s))
          @blob.importers += [self.class.to_s]
          @blob.save!
        end
      end
      return processed
    end

    def log_skip(key, reason)
      Importer::SKIP_LOG.info "commit=#{@commit.try(:revision)} blob=#{@blob.sha} file=#{file.path} key=#{key} #{reason}"
    end

    File = Struct.new(:path, :contents, :locale)

    class Receiver
      attr_reader :importer, :locale

      def initialize(importer, locale=nil)
        @importer = importer
        @locale   = locale
      end

      def add_string(key, value, options={})
        if locale
          @importer.add_translation key, value, locale
        else
          @importer.add_string key, value, {source: importer.file.path}.merge(options)
        end
      end
    end
  end

  # @private
  class NoEncodingFound < StandardError
  end

  # A log of skipped files and keys.
  SKIP_LOG = ActiveSupport::BufferedLogger.new(Rails.root.join('log', "skip-#{Rails.env}.log"))
end
