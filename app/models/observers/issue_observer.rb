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

# This observer on the {Issue} model.
#
# 1. Sends an email to relevant people alerting them of a new issue.
# 2. Sends an email to relevant people alerting them of an updated issue.

class IssueObserver < ActiveRecord::Observer
  def after_create(issue)
    IssueMailer.issue_created(issue).deliver
  end

  def after_update(issue)
    if !issue.skip_email_notifications && (issue.changed - Issue::SKIPPED_FIELDS_FOR_EMAIL_ON_UPDATE).present?
      IssueMailer.issue_updated(issue).deliver
    end
  end
end
