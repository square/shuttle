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
  factory :user do
    sequence(:email) { |i| "email-#{i}@example.com" }
    password "password934723762356"
    first_name "Sancho"
    last_name "Sample"

    trait :confirmed do
      confirmed_at { Time.now }
    end

    trait :activated do
      role { 'monitor' }
      confirmed_at { Time.now }
    end

    trait :translator do
      role { 'translator' }
    end

    trait :reviewer do
      role { 'reviewer' }
    end

    trait :monitor do
      role { 'monitor' }
    end

    trait :admin do
      role { 'admin' }
    end
  end
end
