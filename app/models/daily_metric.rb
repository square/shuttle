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

class DailyMetric < ActiveRecord::Base
  serialize :num_commits_loaded_per_project,    Hash
  serialize :avg_load_time_per_project,         Hash
  serialize :num_commits_completed_per_project, Hash
  serialize :num_words_created_per_language,    Hash
  serialize :num_words_completed_per_language,  Hash

  validates :num_commits_loaded,
            :avg_load_time,
            :num_commits_completed,
            :num_words_created,
            :num_words_completed,
            presence: true

  validates :date, presence: true
end
