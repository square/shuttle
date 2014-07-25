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

# Calls {Project#commit!}.

class CommitCreator
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.
  # @param [String] sha The SHA of the commit to create
  # @param [Hash] options Additional options.
  # @option options [Hash] other_fields Additional model fields to set. Must
  #   have already been filtered for accessible attributes.

  def perform(project_id, sha, options={})
    options.symbolize_keys!
    project = Project.find(project_id)
    # project.repo &:fetch # this looks like a good idea in case a dynamic ref like "HEAD" is given. But, the cost is too high. Doesn't seem like dynamic refs are given very often.
    project.commit!(sha, options)
  rescue Git::CommitNotFoundError, Project::NotLinkedToAGitRepositoryError => err
    CommitMailer.notify_import_errors_in_commit_creator(options[:other_fields].try!(:symbolize_keys).try!(:[], :user_id), project_id, sha, err).deliver
  rescue Timeout::Error => err
    Squash::Ruby.notify err, project_id: project_id, sha: sha
    self.class.perform_in 2.minutes, project_id, sha
  end

  include SidekiqLocking
end
