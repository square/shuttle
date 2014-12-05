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

describe DigestField do
  it "should allow a custom field using the :to option" do
    pending "No models use this option yet"
  end

  it "should allow a custom width with the :width option" do
    pending "No models use this option yet"
  end

  it "should create a named scope using the :scope option" do
    expect(Key.source_copy_matches('test').to_sql).
        to eql("SELECT \"keys\".* FROM \"keys\"  WHERE (\"keys\".\"source_copy_sha_raw\" = E'\\\\237\\\\206\\\\320\\\\201\\\\210\\\\114\\\\175\\\\145\\\\232\\\\057\\\\352\\\\240\\\\305\\\\132\\\\320\\\\025\\\\243\\\\277\\\\117\\\\033\\\\053\\\\013\\\\202\\\\054\\\\321\\\\135\\\\154\\\\025\\\\260\\\\360\\\\012\\\\010'::bytea)")
    expect(Key.source_copy_matches('test', 'test2').to_sql).
        to eql("SELECT \"keys\".* FROM \"keys\"  WHERE (\"keys\".\"source_copy_sha_raw\" IN (E'\\\\237\\\\206\\\\320\\\\201\\\\210\\\\114\\\\175\\\\145\\\\232\\\\057\\\\352\\\\240\\\\305\\\\132\\\\320\\\\025\\\\243\\\\277\\\\117\\\\033\\\\053\\\\013\\\\202\\\\054\\\\321\\\\135\\\\154\\\\025\\\\260\\\\360\\\\012\\\\010'::bytea, E'\\\\140\\\\060\\\\072\\\\342\\\\053\\\\231\\\\210\\\\141\\\\274\\\\343\\\\262\\\\217\\\\063\\\\356\\\\301\\\\276\\\\165\\\\212\\\\041\\\\074\\\\206\\\\311\\\\074\\\\007\\\\155\\\\276\\\\237\\\\125\\\\214\\\\021\\\\307\\\\122'::bytea))")
  end

  it "should automatically set the value from a different field" do
    k = FactoryGirl.build(:key, key: 'hello world')
    expect(k).to be_valid
    expect(k.key_sha_raw).to eql(Digest::SHA2.digest('hello world'))
    k.key = 'foo bar'
    expect(k).to be_valid
    expect(k.key_sha_raw).to eql(Digest::SHA2.digest('foo bar'))
  end
end
