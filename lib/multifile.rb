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

# Adds the ability to generate a gzipped tarball of multiple files.

module Multifile
  protected

  # Call this method to build a gzipped TAR archive of your files. The block is
  # passed a {Receiver} that is used to add files to the archive. The resulting
  # archive data is returned in string format.
  #
  # @yield receiver
  # @yieldparam [Receiver] receiver An object used to add files to the archive.
  # @return [String] The archive data.

  def build_archive
    buffer = ''.encode('BINARY')
    Archive.write_open_memory(buffer, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
      yield Receiver.new(archive)
    end
    return buffer
  end

  # Proxy object used to add files to an archive.

  class Receiver
    # @private
    def initialize(archive)
      @archive     = archive
      @added_files = Set.new
    end

    # Adds a file to the archive.
    #
    # @param [String] path The full path of the file relative to the archive
    #   root.
    # @param [String] data The file contents.
    # @param [Hash] options Additional options.
    # @option options [true, false] :overwrite (true) If `false`, will not add
    #   the file if it has already been added.

    def add_file(path, data, options={})
      options[:overwrite] = true unless options.include?(:overwrite)
      return if !options[:overwrite] && @added_files.include?(path)

      @archive.new_entry do |entry|
        entry.pathname = path
        entry.filetype = 0100000    # normal file
        entry.size     = data.bytesize
        entry.mode     = 0100644    # rw-r--r--

        entry.atime      = Time.now
        entry.ctime      = Time.now
        entry.mtime      = Time.now

        @archive.write_header entry
        @archive.write_data data
      end

      @added_files << path
    end
  end
end
