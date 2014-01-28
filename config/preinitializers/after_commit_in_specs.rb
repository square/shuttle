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

# Move after-commit hooks to after-save in test

class ActiveRecord::Base
  class << self
    def after_commit_with_hack(*args, &block)
      options = args.extract_options!
      case options.delete(:on)
        when :create
          after_create *args, &block
        when :update
          after_update *args, &block
        when :destroy
          after_destroy *args, &block
        else
          after_save *args, &block
          after_destroy(*args, &block) unless options[:if] == :persisted?
      end
    end

    alias_method_chain :after_commit, :hack
  end
end if Rails.env.test?
