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

# Helper module for writing out cached files to the file system. Handles byte
# manipulation and making sure you don't cache empty files.

module Precompiler
  extend ActiveSupport::Concern

  protected

  # Writes a file containing a precompiled manifest or localization to disk.
  #
  # @param [String] file_path The path to create the file in.
  # @yield A block that generates a file to be written.
  # @yieldreturn [Compiler::File] The file to write to disk.

  def write_precompiled_file(file_path)
    begin
      io = yield.io
      data = io.read

      File.open(file_path, 'wb') do |f|
        data.each_byte { |byte| f.putc byte }
      end
    ensure
      FileUtils.rm_f(file_path) if File.exists?(file_path) && File.size(file_path) == 0
    end
  end
end
