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

# Adds additional helpers to Process.

module Process

  # Checks if a PID refers to a running process.
  #
  # @param [Fixnum] pid A process ID.
  # @return [true, false] Whether a process with that PID is running.

  def self.exist?(pid)
    begin
      Process.getpgid pid
      true
    rescue Errno::ESRCH
      false
    end
  end
end
