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
# It loads everything lazily to minimize overhead of unused variables.
# This presenter only cares about the active issues (ie. disregards issues in inactive keys of Articles).

class ArticleOrCommitIssuesPresenter

  attr_reader :item

  # Initializes an instance of the presenter class
  #   @param [Commit, Article] item The {Commit} or {Article} about which the data will be presented.

  def initialize(item)
    @item = item
  end

  # Returns a list of issues related to the Commit/Article.
  # The issues eager loads necessary associations for performance.
  #   @return [Array<Issue>] an array of issues associated with the Commit/Article

  def issues
    @_issues ||= item.active_issues.includes(translation: { key: [{ section: { article: :project } }, :project] }).order_default
  end

  # Counts the number of issues for each possible status.
  # If a status is not encountered in the issues related to this Commit/Article, its count is set to 0.
  # The information is represented as an Array of Hashes. Each hash contains status, status_desc, count fields.
  # Each possible status from the locale file will be included.
  # The issues eager loads necessary associations for performance.
  #   @return [Array<Hash>] an array of hashes that each include details mentioned above
  #
  # @example
  #   ArticleOrCommitIssuesPresenter.new(Commit.first).status_counts #=>
  #           [{status: 1, status_desc: 'Open', count: 10}, {status: 2, status_desc: 'In Progress', count: 0}, etc...]

  def status_counts
    return @_status_counts if @_status_counts
    issues_grouped_by_status = item.active_issues.group('issues.status').select("count(*) as count, issues.status")

    status_to_count_hsh = issues_grouped_by_status.reduce({}) do |hsh, issue_group|
      hsh[issue_group.status] = issue_group.count
      hsh
    end

    @_status_counts = I18n.t('models.issue.status').map do |status, status_desc|
      {
        status: status,
        status_desc: status_desc,
        count: (status_to_count_hsh[status] || 0)
      }
    end
  end

  # Returns a JSON representation of this presenter
  #   @return [Hash] a hash with issues and status_counts

  def as_json(options={})
    {
      issues: issues.map { |i| i.as_json(options) },
      status_counts: status_counts
    }
  end

  # This generates a label to be used for the tabs in the Commit/Article page.
  # If there are pending issues associated with this Commit/Article, it will be shown in parenthesis.
  #   @return [String] a string with pending issues count appended if there are any
  def issues_label_with_pending_count
    @_label ||= "ISSUES" + (pending_issues_count > 0 ? " (#{pending_issues_count})" : "")
  end

  private

  #   @return [Fixnum] number of pending issues associated with this Commit/Article
  def pending_issues_count
    @_pending_issues_count ||= item.issues.pending.count
  end
end
