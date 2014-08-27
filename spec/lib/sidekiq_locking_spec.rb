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

describe "SidekiqLockingSpec" do
  class TestWorker
    include Sidekiq::Worker
    sidekiq_options queue: :low

    def perform(*args)
    end

    include SidekiqLocking
  end

  before :each do
    Shuttle::Redis.flushall
  end

  describe "#perform_with_locking" do
    it "unlocks the mutex and calls perform_without_locking" do
      args = [{ 1 => 2 }]
      TestWorker.send(:mutex, *args).lock
      expect(Shuttle::Redis.keys('*')).to eql(["Redis::Mutex:testworker:[{\"1\":2}]"])

      test_worker = TestWorker.new
      expect(test_worker).to receive(:perform_without_locking)
      test_worker.perform_with_locking *args
      expect(Shuttle::Redis.keys('*')).to eql([])
    end
  end

  describe "#perform_once" do
    let(:sample_args) { [1, 'a', { b: 'c', 2 => :d }] }

    it "doesn't call perform_async if the mutex is already locked" do
      TestWorker.send(:mutex, *sample_args).lock
      expect(TestWorker).to_not receive(:perform_async)
      TestWorker.perform_once(*sample_args)
    end

    it "calls perform_async if mutex doesn't exist" do
      expect(TestWorker).to receive(:perform_async).once.with(*sample_args)
      TestWorker.perform_once(*sample_args)
    end
  end

  describe "#unlock" do
    it "unlocks a previously locked mutex (with simple hash as args)" do
      args = [{ 1 => 2 }]
      expect(TestWorker.send(:mutex, *args).lock).to be_true
      expect(Shuttle::Redis.keys('*')).to eql(["Redis::Mutex:testworker:[{\"1\":2}]"])
      expect(TestWorker.unlock(*args)).to be_true
      expect(Shuttle::Redis.keys('*')).to eql([])
    end

    it "unlocks a previously locked mutex (with complex args)" do
      args = [1, 'a', { b: 'c', 2 => :d }]
      expect(TestWorker.send(:mutex, *args).lock).to be_true
      expect(Shuttle::Redis.keys('*')).to eql(["Redis::Mutex:testworker:[1,\"a\",{\"b\":\"c\",\"2\":\"d\"}]"])
      expect(TestWorker.unlock(*args)).to be_true
      expect(Shuttle::Redis.keys('*')).to eql([])
    end
  end

  describe "#lock_name" do
    it "returns lock name with class name and (simple) arguments" do
      expect(TestWorker.send(:lock_name, "hi")).to eql("testworker:[\"hi\"]")
    end

    it "returns lock name with class name and (simple) arguments" do
      expect(TestWorker.send(:lock_name, 1)).to eql("testworker:[1]")
    end

    it "returns lock name with class name and (complex) arguments" do
      expect(TestWorker.send(:lock_name, 1, 'a', { b: 'c', 2 => :d })).to eql("testworker:[1,\"a\",{\"b\":\"c\",\"2\":\"d\"}]")
    end
  end

  describe "#mutex" do
    it "returns a mutex with the correct name" do
      args = [1, 'a', { b: 'c', 2 => :d }]
      mutex = TestWorker.send(:mutex, *args)
      expect(mutex).to be_a_kind_of(Redis::Mutex)
      expect(mutex.key).to eql(TestWorker.send(:lock_name, *args))
    end
  end

  context "[INTEGRATION TESTS]" do
    describe "#perform_once" do
      [
        ['no arguments', []],
        ['1 argument', ['test']],
        ['1 argument', ['3']],
        ['1 argument', [3]],
        ['2 arguments', [18, "abc"]],
        ['a simple hash', [{ "1" => 2 }]],
        ['a simple hash', [{ 1 => 2 }]],
        ['a simple hash', [{ a: "b" }]],
        ['a complicated hash', [{ 1 => { 2 => { {3=>4} => 5 } } }] ],
        ['a complicated hash', [{ a: { b: "c" }}]],
        ['complicated arguments including hashes', [18, "abc", { other_fields: { description: "This is a test job" }}]],
      ].each do |desc, args|
        it "will clean up the mutex right before a job starts running for a worker with #{desc}" do
          TestWorker.any_instance.stub(:perform_without_locking) # to prevent the job from running so that we know the mutex is cleared before the contents of the perform action is run
          TestWorker.perform_once(*args)
          expect(Shuttle::Redis.keys('*')).to eql([])
        end
      end
    end
  end
end
