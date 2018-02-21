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

require 'rails_helper'
require 'rake'

RSpec.describe 'commit_fingerprint:update' do
  subject { Rake::Task['commit_fingerprint:update'].execute }

  before :all do
    Rake.application.rake_require "tasks/commit_fingerprint"
    Rake::Task.define_task(:environment)
  end

  it 'should calculate and save a fingerprint for each commit' do
    commit = FactoryBot.create(:commit, fingerprint: nil)
    key1 = FactoryBot.create(:key, commits: [commit])
    key2 = FactoryBot.create(:key, commits: [commit])

    subject

    expected_fingerprint = Digest::SHA1.hexdigest([key1.id, key2.id].join(','))
    commit.reload
    expect(commit.fingerprint).to eq(expected_fingerprint)
    expect(commit.duplicate).to be false
  end

  it 'should mark duplicate commits as such, keeping the oldest commit as active' do
    key1 = FactoryBot.create(:key)
    key2 = FactoryBot.create(:key)
    expected_fingerprint = Digest::SHA1.hexdigest([key1.id, key2.id].join(','))

    commit1 = FactoryBot.create(:commit) # oldest commit
    commit2 = FactoryBot.create(:commit)

    commit1.keys << key1
    commit2.keys << key1

    commit1.keys << key2
    commit2.keys << key2

    subject

    commit1.reload
    commit2.reload

    expect(commit1.fingerprint).to eq(expected_fingerprint)
    expect(commit2.fingerprint).to eq(expected_fingerprint)
    expect(commit1.duplicate).to be false
    expect(commit2.duplicate).to be true
  end
end
