# encoding: utf-8

# Copyright 2018 Square Inc.
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

FactoryBot.define do
  factory :translation_change do
    association :project
    association :user
    association :translation
    is_edit     false
    sha         'cbf1b9bf524cf643467060e475e40e88593b434d'
    role        'translator'
  end
end
