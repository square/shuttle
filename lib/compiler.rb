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
  # @option options [true, false] force (false) If `true`, busts the cache and
  #   forces a recompile.
  # @return [File] Output data and metadata.
  # @raise [CommitNotReadyError] If the Commit is not ready and a non-partial
  #   manifest is requested.
  # @raise [UnknownLocaleError] If the RFC 5646 code for `locale` is not
  #   recognized.
  # @raise [UnknownExporterError] If no exporter can be found to handle
  #   `format`.

  def manifest(format, options={})
    raise CommitNotReadyError if !@commit.ready? && !options[:partial]

    if options[:locale]
      locale = Locale.from_rfc5646(options[:locale])
      raise UnknownLocaleError unless locale
    else
      locale = nil
    end

    exporter = Exporter::Base.find_by_format(format)
    raise UnknownExporterError unless exporter

    if !options[:force] && locale.nil? && (data = cached_manifest(format))
      return File.new(
          StringIO.new(data),
          exporter.character_encoding,
          "#{locale.try!(:rfc5646) || 'manifest'}.#{exporter.file_extension}",
          exporter.mime_type
      )
    end

    io = StringIO.new
    exporter = exporter.new(@commit)
    exporter.export io, *locales_for_export(locale, options[:partial])
    io.rewind

    return File.new(
        io,
        exporter.class.character_encoding,
        "#{locale.try!(:rfc5646) || 'manifest'}.#{exporter.class.file_extension}",
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
  # @option options [true, false] force (false) If `true`, busts the cache and
  #   forces a recompile.
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
    if !options[:force] && locale.nil? && (data = cached_localization)
      return File.new(
          StringIO.new(data),
          nil,
          filename,
          'application/x-gzip'
      )
    end

    data = Localizer::Base.localize(@commit, *locales_for_export(locale, options[:partial]))

    File.new(
        StringIO.new(data),
        nil,
        filename,
        'application/x-gzip'
    )
  end

  private

  def locales_for_export(locale, partial)
    if locale
      Array.wrap(locale)
    else
      (partial ? @commit.project.targeted_locales : @commit.project.required_locales) - [@commit.project.base_locale]
    end
  end

  def cached_manifest(format)
    contents = Shuttle::Redis.get(ManifestPrecompiler.new.key(@commit, format))
    if contents && valid_manifest?(contents, format)
      return contents
    else
      Shuttle::Redis.del ManifestPrecompiler.new.key(@commit, format)
      return nil
    end
  end

  def cached_localization
    contents = Shuttle::Redis.get(LocalizePrecompiler.new.key(@commit))
    if contents && valid_manifest?(contents, 'tgz')
      return contents
    else
      Shuttle::Redis.del LocalizePrecompiler.new.key(@commit)
      return nil
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

    # Closes the `io` stream if appliable.

    def close
      io.close if io.respond_to?(:close)
    end
  end

  # Raised when a Commit is not marked as ready.
  class CommitNotReadyError < StandardError; end

  # Raised when an unknown RFC 5646 code is supplied.
  class UnknownLocaleError < StandardError; end

  # Raised when no exporter can be found for a given format.
  class UnknownExporterError < StandardError; end
end
