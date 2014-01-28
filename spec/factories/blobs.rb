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
  factory :blob do
    association :project
    sequence(:sha) { |i| i.to_s(16).rjust(40, '0') }
    skip_sha_check true
  end

  factory :fake_blob, parent: :blob do
    after(:create) do |blob, evaluator|
      blob.stub(:blob).and_return(OpenStruct.new(contents: 'hello, world', sha: evaluator.sha))
    end
  end
end
