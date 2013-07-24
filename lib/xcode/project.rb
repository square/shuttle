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

  # An in-memory representation of an Xcode project file. Parses the ASCII-style
  # plist file, and lazy-loads project objects.

  class Project

    # Instantiates a new Project from a pbxproj file contents.
    #
    # @param [String] contents The contents of a pbxproj.
    # @raise [Parslet::ParseFailed] If the file is invalid.
    # @raise [StandardError] If the file is of the correct archive version.

    def initialize(contents)
      @data = parse(contents).first

      raise "Invalid project file" unless @data['archiveVersion'] == '1'
    end

    # @return [Hash<String, Xcode::Target>] A hash mapping a target's unique
    #   identifier to a target within this project.

    def targets
      @targets ||= begin
        targets = objects_of_type('PBXNativeTarget').
            inject({}) { |hsh, (id, o)| hsh[id] = Target.new(self, o); hsh }
        targets.values.each { |t| t.resolve_dependencies targets }
        targets
      end
    end

    # @return [Hash<String, Xcode::BuildPhase::Sources>] A hash mapping a build
    #   phase's unique identifier to a source files build phase within this
    #   project.

    def source_phases
      @build_phases ||= objects_of_type('PBXSourcesBuildPhase').
          inject({}) { |hsh, (id, o)| hsh[id] = BuildPhase::Sources.new(self, o); hsh }
    end

    # @return [Hash<String, Xcode::BuildFile>] A hash mapping a build file
    #   reference's unique identifier to a build file reference within this
    #   project.

    def build_files
      @build_files ||= objects_of_type('PBXBuildFile').
          inject({}) { |hsh, (id, o)| hsh[id] = BuildFile.new(self, o); hsh }
    end

    # @return [Hash<String, Xcode::File>] A hash mapping a file's unique
    #   identifier to a file within this project.

    def files
      @files ||= begin
        files = objects_of_type('PBXFileReference').
            inject({}) { |hsh, (id, o)| hsh[id] = Xcode::File.new(self, o); hsh }
        # associate each file with its enclosing group
        groups.each { |_, group| group.resolve_children files }
        files
      end
    end

    # @return Hash<String, Xcode::Group>] A hash mapping a group's unique
    #  identifier to the Group object within this project.

    def groups
      @groups ||= begin
        groups = objects_of_type('PBXGroup').
            inject({}) { |hsh, (id, o)| hsh[id] = Group.new(self, o); hsh }
        objects_of_type('PBXVariantGroup').each { |id, o| groups[id] = Group.new(self, o) }
        # associate each group with its enclosing group
        groups.each { |_, g| g.resolve_children groups }
        groups
      end
    end

    # @private
    def inspect() "#<#{self.class.to_s} (#{@data['objects'].size} objects)>" end

    # @return [String] The project's root path.
    def root() project['projectRoot'] end

    private

    def project
      @project ||= objects_of_type('PBXProject')[@data['rootObject']]
    end

    def objects_of_type(type)
      @data['objects'].select { |_, o| o['isa'] == type }
    end

    def parse(contents)
      Transformer.new.apply Parser.new.parse(contents)
    end

    # @private
    class Parser < Parslet::Parser
      rule(:ws) { (str(' ') | str("\t") | str("\r") | str("\n")) }
      rule(:ws?) { ws.repeat }
      rule(:nl) { str("\n") | str("\r") }

      rule(:block_comment) { str('/*') >> (str('*/').absent? >> any).repeat >> str('*/') }
      rule(:line_comment) { str('//') >> (nl.absent? >> any).repeat >> nl }
      rule(:comment) { block_comment | line_comment }

      rule(:wsc) { ws | comment }
      rule(:wsc?) { wsc.repeat }

      rule(:quote) { str('"') }
      rule(:nonquote) { str('"').absent? >> any }
      rule(:escape) { str('\\') >> any }

      rule(:nsstring) do
        quote >> (escape | nonquote).repeat.as(:NSString) >> quote |
            match('[a-zA-Z0-9_./]').repeat(1).as(:NSString)
      end
      rule :nsdata do
        str('<') >> match('[0-9a-fA-F ]').repeat.as(:NSData) >> str('>')
      end
      rule :nsarray do
        str('(') >> wsc? >> (value >> (wsc? >> str(',') >> wsc? >> value).repeat).maybe.as(:NSArray) >> wsc? >> (str(',') >> wsc?).maybe >> str(')')
      end
      rule(:pair) { nsstring.as(:key) >> wsc? >> str('=') >> wsc? >> value.as(:value) >> wsc? >> str(';') }
      rule :nsdictionary do
        str('{') >> wsc? >> (pair >> wsc?).repeat.as(:NSDictionary) >> str('}')
      end

      rule(:value) { nsdictionary | nsarray | nsdata | nsstring }

      rule(:statement) { ws | comment | nsdictionary }
      rule(:statements) { statement.repeat }

      root :statements
    end

    # @private
    class Transformer < Parslet::Transform
      rule(NSString: subtree(:x)) do
        x == [] ? '' : x.to_s
      end
      rule(NSData: subtree(:x)) do
        x == [] ? '' : x.to_s.gsub(/\s/, '').scan(/.{2}/).map { |c| c.to_i(16) }.pack('C*')
      end
      rule(NSArray: subtree(:x)) { Array.wrap(x) }
      rule(NSDictionary: subtree(:x)) { x.inject({}) { |hsh, subtree| hsh[subtree[:key]] = subtree[:value]; hsh } }
    end
  end
end
