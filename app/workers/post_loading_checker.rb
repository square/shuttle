# Copyright 2019 Square Inc.
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

# Processing the Commit, Article or Asset after loading them into Shuttle.

class PostLoadingChecker
  include Sidekiq::Worker
  sidekiq_options queue: :high

  VALIDATORS = [
      TranslationValidator::SourceFencerValidator,
      TranslationValidator::TranslationAutoMigration,
  ]

  def perform(job_type, job_id)
    job = find_job(job_type, job_id)
    return if job.nil?

    VALIDATORS.each do |validator|
      begin
        validator.new(job).run
      rescue => e
        Rails.logger.error("#{PostLoadingChecker} - Failed to run #{validator} on (#{job_type}, #{job_id})")
        Rails.logger.info("#{PostLoadingChecker} - due to exception: #{e.inspect}")
      end
    end
  end

  def find_job(job_type, job_id)
    case job_type
    when 'commit'
      Commit.where(id: job_id).first
    when 'article'
      Article.where(id: job_id).first
    when 'asset'
      Asset.where(id: job_id).first
    else
      raise ArgumentError, "invalid model type: #{job_type}, #{job_id}"
    end
  end

  def self.launch(job)
    PostLoadingChecker.perform_once(job.project.job_type, job.id)
  end

  include SidekiqLocking
end
