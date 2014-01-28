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

require 'spec_helper'

describe GitObjectField do
  it "should validate the Git object type when :git_type is set" do
    Project.where(repository_url: 'git://github.com/RISCfuture/better_caller.git').delete_all
    blob = FactoryGirl.build(:blob, project: FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git'))
    blob.skip_sha_check = false

    blob.sha = 'f7cdffe98b1fc5b31e66a6f1f1b7404d34c3c73e'
    expect(blob).to be_valid

    blob.sha = '16bb6ab08c7f16cacab049fe6c89ca392ef01867'
    expect(blob).not_to be_valid
    expect(blob.errors[:sha]).to eql(['does not exist in the Git repository'])

    blob.sha = 'ab3e6137ea47c8e55d9ab9720a3f3a0587ab61e7'
    expect(blob).not_to be_valid
    expect(blob.errors[:sha]).to eql(['is not the correct Git object type'])
  end
end
