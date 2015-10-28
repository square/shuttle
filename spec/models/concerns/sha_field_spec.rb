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
  class FakeShaFieldImpl
    include ActiveModel::Validations

    attr_accessor :sha, :sha_raw

    extend ShaField
    sha_field :sha
  end

  it "should read and write a SHA to a BYTEA column" do
    b = FakeShaFieldImpl.new
    b.sha = 'aeae59c36b4849bc7f7a5e29d979baba2941760a'
    expect(b.sha_raw).to eql(ShaField::unhex('aeae59c36b4849bc7f7a5e29d979baba2941760a'))
    b.sha_raw = ShaField::unhex('38ac2197e79bde048828e51d6616c9247f5029c0')
    expect(b.sha).to eql('38ac2197e79bde048828e51d6616c9247f5029c0')
  end

  it "should allow a custom column name" do
    pending "No models use this option yet"
  end

  it "should allow additional validation options" do
    pending "No models use this option yet"
  end

  it "should create a named scope using the :scope option" do
    expect(Blob.with_sha('aeae59c36b4849bc7f7a5e29d979baba2941760a').to_sql).
        to eql("SELECT \"blobs\".* FROM \"blobs\"  WHERE \"blobs\".\"sha\" = 'aeae59c36b4849bc7f7a5e29d979baba2941760a'")
  end
end
