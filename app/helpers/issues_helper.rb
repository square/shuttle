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

# Helper methods that are related to Issues.

module IssuesHelper

  # The url to view an issue.
  # Issue can be viewed in both an edit translation page and show translation page.
  # If `user` is provided, and is a translator, this will produce the issue url within
  # the edit translation page.
  #
  # @param [Issue] issue The issue of interest.
  # @param [User] user The user who will see this url.
  # @return [String] Url of the issue in the project_key_translation page, with the section identifier.

  def issue_url(issue, user=nil)
    raise ArgumentError, "Issue must be provided" unless issue.is_a?(Issue)

    args = [issue.translation.key.project, issue.translation.key, issue.translation, anchor: "issue-wrapper-#{issue.id}"]
    (user.try(:translator?) ? edit_project_key_translation_url(*args) : project_key_translation_url(*args))
  end
end
