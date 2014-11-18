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

# Helper methods for the Layout.

module LayoutHelper

  # The class attribute of the html body tag.
  #
  # By default, this will be set to the controller name, however extra values
  # can be provided in the view file via `content_for` and they will be
  # added to the class attribute.

  def body_class
    c = controller_name
    c += " " + content_for(:class) if content_for?(:class)
    c
  end

  # The id attribute of the html body tag.
  #
  # By default, this will be set to a string that combines the the controller
  # name and the action name. A custom id for a specific page can be achieved
  # with content_for in that specific page. Ex: `content_for(:id, "my_custom_id")`

  def body_id
    content_for(:id) || "#{controller_name}-#{action_name}"
  end
end
