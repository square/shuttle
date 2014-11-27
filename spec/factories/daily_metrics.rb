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

FactoryGirl.define do
  factory :daily_metric do
    date                                { Time.utc(2014, 8, 12) }
    num_commits_loaded                  5
    num_commits_loaded_per_project      { {'Project One' => 3, 'Project Two' => 2} }
    avg_load_time                       3.0
    avg_load_time_per_project           { {'Project One' => 2.0, 'Project Two' => 4.0} }
    num_commits_completed               3
    num_commits_completed_per_project   { {'Project One' => 2, 'Project Two' => 1} }
    num_words_created                   50
    num_words_created_per_language      { {'jp' => 30, 'fr' => 20} }
    num_words_completed                 30
    num_words_completed_per_language    { {'jp' => 20, 'fr' => 10} }
  end
end
