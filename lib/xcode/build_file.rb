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

module Xcode

  # A reference to a source file for the purposes of building. Used by
  # {Xcode::BuildPhase::Sources} to indicate which files should be built in a
  # source files build phase.

  class BuildFile
    # @return [Xcode::Project] The project this file reference belongs to.
    attr_reader :project

    # @private
    def initialize(project, data)
      @project = project
      @data    = data
    end

    # @return [Xcode::File] The source file that should be built.
    def file() @file ||= project.files[@data['fileRef']] end

    # @private
    def inspect() "#<#{self.class.to_s} (-> #{@data['fileRef']})>" end
  end
end
