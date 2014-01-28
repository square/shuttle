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
describe ManifestPrecompiler do
  describe "#perform" do
    before(:each) do
      @commit = FactoryGirl.create(:commit)
      @format = 'yaml'
      @key = FactoryGirl.create(:key, project: @commit.project)
      @translation = FactoryGirl.create(:translation, key: @key, translated: true, approved: true, copy: "Foo", source_copy: "Bar")
      Shuttle::Redis.del ManifestPrecompiler.new.key(@commit, @format)
      @commit.keys << @key
      expect(@translation).to be_present
      @commit.recalculate_ready!
      expect(@commit).to be_ready
      @cache_key = ManifestPrecompiler.new.key(@commit, @format)
    end

    it "compiles a given commit and stores the files on disk" do
      expect(Shuttle::Redis.exists(@cache_key)).to be_false
      ManifestPrecompiler.new.perform(@commit.id, @format)
      expect(Shuttle::Redis.exists(@cache_key)).to be_true
      expect(Shuttle::Redis.get(@cache_key)).to include(@translation.copy)
    end

    context "if an exception is thrown" do
      it "does not write an empty file" do
        precompiler = ManifestPrecompiler.new
        allow(Shuttle::Redis).to receive(:set).and_raise(RuntimeError)
        expect(Shuttle::Redis.exists(@cache_key)).to be_false
        expect { precompiler.perform(@commit.id, @format) }.to raise_error(RuntimeError)
        expect(Shuttle::Redis.exists(@cache_key)).to be_false
      end
    end

    it "unlocks the correct mutex" do
      precompiler = ManifestPrecompiler.new
      mutex = precompiler.class.__send__(:mutex, @commit.id, @format)
      mutex.lock!

      expect { precompiler.perform(@commit.id, @format) }.to change{mutex.locked?}.from(true).to(false)
    end
  end
end
