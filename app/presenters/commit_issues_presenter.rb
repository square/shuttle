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

# A presenter that handles the instance variables needed to populate the commits/issues page.

class CommitIssuesPresenter

  # Initializes an instance of the presenter class with the given {Commit}
  #   @param [Commit] commit The {Commit} about which the data will be presented.

  def initialize(commit)
    @commit = commit
  end

  # Returns a list of issues related to the commit.
  # The issues eager loads necessary associations for performance.
  #   @return [Array<Issue>] an array of issues associated with the commit

  def issues
    @issues ||= @commit.issues.includes(translation: { key: :project }).order_default
  end

  # Counts the number of issues for each possible status.
  # If a status is not encountered in the issues related to this commit, its count is set to 0.
  # The information is represented as an Array of Hashes. Each hash contains status, status_desc, count fields.
  # Each possible status from the locale file will be included.
  # The issues eager loads necessary associations for performance.
  #   @return [Array<Hash>] an array of hashes that each include details mentioned above
  #
  # Example: [{status: 1, status_desc: 'Open', count: 10}, {status: 2, status_desc: 'In Progress', count: 0}]

  def status_counts
    return @status_counts if @status_counts
    issues_grouped_by_status = @commit.issues.group('issues.status').select("count(issues.id) as count, issues.status")
    status_to_count_hsh = issues_grouped_by_status.reduce({}) {|hsh, issue_group| hsh[issue_group.status] = issue_group.count; hsh}
    @status_counts = I18n.t('models.issue.status').map { |status, status_desc| { status: status, status_desc: status_desc, count: (status_to_count_hsh[status] || 0) } }
  end

  # Returns a JSON representation of this presenter
  #   @return [Hash] a hash with issues and status_counts

  def as_json(*args)
    { issues: issues.as_json(*args),
      status_counts: status_counts.as_json(*args) }
  end
end
