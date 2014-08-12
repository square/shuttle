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
  factory :project do
    name "Example Project"
    sequence(:repository_url) { |i| "git://git.example.com/square/project-#{i}.git" }
    base_rfc5646_locale 'en-US'
    targeted_rfc5646_locales 'en-US' => true, 'de-DE' => true
    validate_repo_connectivity false

    trait :light do
      repository_url  { Rails.root.join('spec', 'fixtures', 'repository-light.git').to_s }
      skip_imports    { Importer::Base.implementations.map(&:ident) - %w(yaml) }
    end
  end
end
