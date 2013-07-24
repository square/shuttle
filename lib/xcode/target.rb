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

  # A representation of a build target within an Xcode project.

  class Target
    # @return [Array<Xcode::Target>] All targets that depend on this target.
    attr_reader :dependencies
    # @return [Xcode::Project] The project containing this target.
    attr_reader :project

    def initialize(project, data)
      @project = project
      @data    = data
    end

    # @return [String] The name of the target.
    def name() @name ||= @data['name'] end

    # @private
    def inspect() "#<#{self.class.to_s} #{name}>" end

    # @private
    def resolve_dependencies(targets)
      @dependencies = @data['dependencies'].map { |id| targets[id] }.compact
    end

    # @return [Array<Xcode::BuildPhase::Sources>] The source files build phases
    #   in this target.

    def source_phases
      @build_phases ||= @data['buildPhases'].map { |id| project.source_phases[id] }.compact
    end

    # @return [Array<String>] The unique list of all source file paths this
    #   target uses.

    def all_paths
      source_phases.map(&:files).flatten.uniq.map(&:file).map(&:full_path).uniq
    end
  end
end
