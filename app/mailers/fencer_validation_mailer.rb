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

# Sends emails related to Comments

class FencerValidationMailer < ActionMailer::Base
  include ActionView::Helpers::TextHelper

  default from: Shuttle::Configuration.mailer.from

  # Notifies shuttle team and localization team about suspicious source strings.
  #
  # @return [Mail::Message] The email to be delivered.

  def suspicious_source_found(job, suspicious_keys_errors)
    @job = job
    @suspicious_keys_errors = suspicious_keys_errors

    @author_name = author_name
    @author_email = author_email
    @job_url = job_url
    @formatted_keys_errors = formatted_keys_errors

    mail_addresses = [Shuttle::Configuration.mailer.from, Shuttle::Configuration.mailer.localization_list]
    if Rails.env.production?
      subject = t('mailer.fencer_validation.suspicious_translation_found.subject.production')
    else
      subject = t('mailer.fencer_validation.suspicious_translation_found.subject.staging')
    end
    mail to: mail_addresses, subject: subject
  end

  def author_name
    case @job.project.job_type
    when 'commit'
      @job.author || author_email
    when 'article'
      author_email
    when 'asset'
      author_email
    else
      raise ArgumentError, "job type not supported: #{job.project.job_type}"
    end
  end

  def author_email
    case @job.project.job_type
    when 'commit'
      @job.author_email
    when 'article'
      @job.email
    when 'asset'
      @job.email
    else
      raise ArgumentError, "job type not supported: #{job.project.job_type}"
    end
  end

  def job_url
    case @job.project.job_type
    when 'commit'
      project_commit_url(@job.project, @job)
    when 'article'
      api_v1_project_article_url(@job.project, @job.name)
    when 'asset'
      project_asset_url(@job.project, @job)
    else
      raise ArgumentError, "job type not supported: #{job.project.job_type}"
    end
  end

  def formatted_keys_errors
    @suspicious_keys_errors.map do |key, reason|
      [
          project_key_translation_url(key.project, key, key.translations.first),
          reason
      ]
    end
  end
end
