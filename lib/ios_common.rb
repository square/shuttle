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

# Code shared in common among all iOS-related importers and exporters.

module IosCommon
  # Include in a string to mark as translatable.
  DO_NOT_LOCALIZE_TOKEN = '<DNL>'

  private

  # strip prefix from class name and humanize
  def display_name_for_class(klass)
    klass.gsub(/^(?:[A-Z]{2})?[A-Z]{3}/) { |match| match.last }.underscore.humanize
  end

  def padded_base64(data)
    return "#{data}==" if data.length() % 3 == 1
    return "#{data}=" if data.length() % 3 == 2
    return data
  end

  def unpadded_base64(string)
    string.sub(/={1,2}$/, '')
  end
end
