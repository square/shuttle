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
  module BuildPhase

    # @abstract
    #
    # Abstract superclass for all target build phases.

    class Base
      # @return [Xcode::Project] The project this build phase is a part of.
      attr_reader :project

      # @private
      def initialize(project, data)
        @project = project
        @data    = data
      end

      # @private
      def inspect() "#<#{self.class.to_s} (#{@data['files'].size} files)>" end
    end
  end
end
