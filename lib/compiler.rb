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

# Performs a manifest or localize operation on a commit. Uses an
# {Exporter::Base exporter} or {Localizer::Base localizer} to generate a file in
# a particular format, and supplies the output to a given `IO`.

class Compiler

  # Creates a new compiler to work with a given Commit.
  #
  # @param [Commit] commit A Commit to manifest.

  def initialize(commit)
    @commit = commit
  end

  # Manifest a commit to a given output stream.
  #
  # @param [String] format The format identifier of an exporter to use, such as
  #   "application/javascript".
  # @param [Hash] options Additional options.
  # @option options [true, false] partial (false) If `true`, non-ready Commits
  #   are allowed, with untranslated strings being omitted.
  # @option options [String] locale The RFC 5646 code for a locale to export, or
  #   `nil` to export all required locales.
  # @return [File] Output data and metadata.
  # @raise [CommitNotReadyError] If the Commit is not ready and a non-partial
  #   manifest is requested.
  # @raise [UnknownLocaleError] If the RFC 5646 code for `locale` is not
  #   recognized.
  # @raise [UnknownExporterError] If no exporter can be found to handle
  #   `format`.

  def manifest(format, options={})
    raise CommitLoadingError if @commit.loading?
    raise CommitNotReadyError if !@commit.ready? && !options[:partial]

    if options[:locale].present?
      locales = options[:locale].split(',')
      locales.map! { |locale| Locale.from_rfc5646(locale) }
      raise UnknownLocaleError if locales.any?(&:nil?)
    else
      locales = []
    end

    exporter = Exporter::Base.find_by_format(format)
    raise UnknownExporterError unless exporter

    io = StringIO.new
    exporter = exporter.new(@commit)
    exporter.export io, *locales_for_export(*locales, options[:partial])
    io.rewind

    filename = locales.size == 1 ? locales.first.rfc5646 : 'manifest'
    return File.new(
        io,
        exporter.class.character_encoding,
        "#{filename}.#{exporter.class.file_extension}",
        exporter.class.mime_type
    )
  end

  # Generates localized versions of localizable files in a commit.
  #
  # @param [Hash] options Additional options.
  # @option options [true, false] partial (false) If `true`, non-ready Commits
  #   are allowed, with untranslated strings being omitted.
  # @option options [String] locale The RFC 5646 code for a locale to use, or
  #   `nil` to use all required locales.
  # @return [File] Output data and metadata.
  # @raise [CommitNotReadyError] If the Commit is not ready and a non-partial
  #   localization is requested.
  # @raise [UnknownLocaleError] If the RFC 5646 code for `locale` is not
  #   recognized.

  def localize(options={})
    raise CommitNotReadyError if !@commit.ready? && !options[:partial]

    if options[:locale]
      locale = Locale.from_rfc5646(options[:locale])
      raise UnknownLocaleError unless locale
    else
      locale = nil
    end

    filename = "#{locale.try!(:rfc5646) || 'localized'}.tar.gz"

    data = Localizer::Base.localize(@commit, *locales_for_export(locale, options[:partial]))

    File.new(
        StringIO.new(data),
        nil,
        filename,
        'application/x-gzip'
    )
  end

  private

  def locales_for_export(*locales, partial)
    if locales.any?
      locales
    else
      (partial ? @commit.project.targeted_locales : @commit.project.required_locales) - [@commit.project.base_locale]
    end
  end

  def valid_manifest?(contents, format)
    case format
      when 'tgz'
        Exporter::Multifile::ClassMethods.valid?(contents)
      else
        exporter = Exporter::Base.find_by_format(format)
        return true unless format # considered valid unless proven otherwise
        exporter.valid?(contents)
    end
  end

  # The output of a manifest or localize operation. Stores the output data and
  # associated metadata for transmission.
  class File < Struct.new(:io, :encoding, :filename, :mime_type)

    # Contents of the file
    def content
      if io.respond_to?(:string)
        str = io.string
      else
        str = io.read
      end
      return str.force_encoding(encoding) if encoding
      str
    end

    # Closes the `io` stream if appliable.
    def close
      io.close if io.respond_to?(:close)
    end
  end

  # Raised when a Commit is still loading.
  class CommitLoadingError < StandardError; end

  # Raised when a Commit is not marked as ready.
  class CommitNotReadyError < StandardError; end

  # Raised when an unknown RFC 5646 code is supplied.
  class UnknownLocaleError < StandardError; end

  # Raised when no exporter can be found for a given format.
  class UnknownExporterError < StandardError; end
end
