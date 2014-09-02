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

# This observer on the {Comment} model.
#
# 1. Sends an email to relevant people alerting them of a new comment.

class CommentObserver < ActiveRecord::Observer
  def after_commit_on_create(comment)
    # send a notification to subscribed email addresses about the new comment
    CommentMailer.comment_created(comment).deliver
  end
end
