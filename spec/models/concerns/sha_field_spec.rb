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

describe ShaField do
  it "should read and write a SHA to a BYTEA column" do
    c = FactoryGirl.build(:commit)
    c.revision = 'aeae59c36b4849bc7f7a5e29d979baba2941760a'
    expect(c.revision_raw).to eql(ShaField::unhex('aeae59c36b4849bc7f7a5e29d979baba2941760a'))
    c.revision_raw = ShaField::unhex('38ac2197e79bde048828e51d6616c9247f5029c0')
    expect(c.revision).to eql('38ac2197e79bde048828e51d6616c9247f5029c0')
  end

  it "should allow a custom column name" do
    pending "No models use this option yet"
  end

  it "should allow additional validation options" do
    pending "No models use this option yet"
  end

  it "should create a named scope using the :scope option" do
    expect(Blob.with_sha('aeae59c36b4849bc7f7a5e29d979baba2941760a').to_sql).
        to eql("SELECT \"blobs\".* FROM \"blobs\"  WHERE (\"blobs\".\"sha_raw\" = E'\\\\256\\\\256\\\\131\\\\303\\\\153\\\\110\\\\111\\\\274\\\\177\\\\172\\\\136\\\\051\\\\331\\\\171\\\\272\\\\272\\\\051\\\\101\\\\166\\\\012'::bytea)")
    expect(Blob.with_sha('aeae59c36b4849bc7f7a5e29d979baba2941760a', '38ac2197e79bde048828e51d6616c9247f5029c0').to_sql).
        to eql("SELECT \"blobs\".* FROM \"blobs\"  WHERE (\"blobs\".\"sha_raw\" IN (E'\\\\256\\\\256\\\\131\\\\303\\\\153\\\\110\\\\111\\\\274\\\\177\\\\172\\\\136\\\\051\\\\331\\\\171\\\\272\\\\272\\\\051\\\\101\\\\166\\\\012'::bytea, E'\\\\070\\\\254\\\\041\\\\227\\\\347\\\\233\\\\336\\\\004\\\\210\\\\050\\\\345\\\\035\\\\146\\\\026\\\\311\\\\044\\\\177\\\\120\\\\051\\\\300'::bytea))")
  end
end
