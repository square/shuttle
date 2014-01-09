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
    Project.find(project_id).commit!(sha, options.symbolize_keys)
  rescue Timeout::Error => err
    self.class.perform_in 2.minutes, project_id, sha
  end

  include SidekiqLocking
end
