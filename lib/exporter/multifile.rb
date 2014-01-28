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

module Exporter

  # Mixin for exporters that adds the ability to export multiple files in a
  # gzipped tarball format. The tarball can be extracted to the project root.
  # This module uses the base {::Multifile} module.
  #
  # You should `include` this module in your exporter and implement the
  # {#export_files} method.

  module Multifile
    extend ActiveSupport::Concern
    include ::Multifile

    # @private
    def export(io, *locales)
      io << build_archive { |receiver| export_files receiver, *locales }
    end

    # @abstract
    #
    # @overload export_files(receiver, locale, ...)
    #   Implement this method to add files to the exported tarball. You can add
    #   a file by calling `receiver.add_file` for each file you wish to export.
    #   @param [::Multifile::Receiver] receiver A proxy object that you can use
    #     to add files to the archive.
    #   @param [Locale] locale A locale to export.

    def export_files(receiver, *locales)
      raise NotImplementedError
    end

    protected

    module ClassMethods
      def file_extension() 'tar.gz' end

      def valid?(contents)
        Archive.read_open_memory(contents, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR)
        return true
      rescue Archive::Error
        return false
      end

      extend self # so others can use valid?
    end
  end
end
