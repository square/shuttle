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

  # @abstract
  #
  # Abstract superclass containing code common to Xcode files and groups.

  class Entry
    # @return [Xcode::Project] The project this file or group is a part of.
    attr_reader :project
    # @return [Xcode::Group, nil] The group that contains this file or group, if
    #   any.
    attr_accessor :parent

    # @private
    def initialize(project, data)
      @project = project
      @data    = data
    end

    # @return [String, :group] The path that the entry's path is relative to, or
    #   `:group` if it is equal to the parent group's path.

    def source_tree
      @source_tree ||= begin
                         case @data['sourceTree']
                           when '<group>' then :group
                           when '<absolute>' then :absolute
                           when 'BUILT_PRODUCTS_DIR' then :built_products
                           when 'DEVELOPER_DIR' then :developer
                           when 'SDKROOT' then :sdk
                           when 'SOURCE_ROOT' then :source
                           else @data['sourceTree']
                         end
      end
    end

    # @return [String] The path to the entry, relative to the enclosing group's
    #   source tree.
    def path() @path ||= @data['path'] end

    # @return [String, :unsupported] The full path to this file or group, or
    #  `:unsupported` if the full path cannot be determined (e.g., it is
    #   relative to a native SDK).

    def full_path
      parent_path = case source_tree
                      when :group
                        if parent
                          if parent.full_path.kind_of?(String)
                            parent.full_path
                          else
                            :unsupported
                          end
                        else
                          project.root
                        end
                      when :source then '/'
                      when :absolute, :built_products, :developer, :sdk then return :unsupported
                      else ''
                    end

      ::File.join(parent_path, (path || ''))
    end

    # @private
    def resolve_children(groups)
      @data['children'].each do |child|
        groups[child].try :parent=, self
      end
    end

    # @private
    def inspect() "#<#{self.class.to_s} #{path}>" end
  end
end
