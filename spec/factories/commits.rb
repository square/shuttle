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
  factory :commit do
    association :project
    sequence(:revision) { rand(16**40).to_s(16).rjust(40, '0') }
    message "Fixed nil error in foo_controller.rb"
    committed_at { Time.now }
    loaded_at { Time.now }
    loading false
    ready false
    skip_import true

    trait :errored_during_import do
      import_errors { [["StandardError", "fake error"]] }
    end
  end
end
