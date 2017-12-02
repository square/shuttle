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

require 'rails_helper'

RSpec.describe DigestField do
  it "should create a named scope using the :scope option" do
    expect(Key.source_copy_matches('test').to_sql).
        to eql("SELECT \"keys\".* FROM \"keys\" WHERE \"keys\".\"source_copy_sha\" = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'")
  end

  it "should automatically set the value from a different field" do
    k = FactoryBot.build(:key, key: 'hello world')
    expect(k).to be_valid
    expect(k.key_sha).to eql(Digest::SHA2.hexdigest('hello world'))
    k.key = 'foo bar'
    expect(k).to be_valid
    expect(k.key_sha).to eql(Digest::SHA2.hexdigest('foo bar'))
  end

  it "should validate _sha field" do
    k = FactoryBot.build(:key, key: nil)
    expect(k).to_not be_valid
    expect(k.errors.messages).to eql(key: ["can’t be blank"],
                                     original_key: ["can’t be blank"],
                                     key_sha: ["is not a valid SHA2 digest", "can’t be blank"])
  end
end
