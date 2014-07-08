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

describe ImportErrors do
  before(:each) do
    @commit = FactoryGirl.build(:commit)
  end

  context "#import_errors_in_redis" do
    it "should return import errors in redis" do
      Shuttle::Redis.sadd("commit:#{@commit.revision}:import_errors", "StandardError - this is a fake error (in /path/to/some/file)")
      expect(@commit.import_errors_in_redis).to eql([["StandardError", "this is a fake error (in /path/to/some/file)"]])
    end
  end

  context "#add_import_error_in_redis" do
    it "should add an import error to commit in redis with the default message" do
      @commit.add_import_error_in_redis(StandardError.new("This is a fake error"))
      expect(@commit.import_errors_in_redis).to eql([["StandardError", "This is a fake error"]])
    end

    it "should add an import error to commit in redis with a custom message" do
      @commit.add_import_error_in_redis(StandardError.new("This is a fake error"), "in /path/to/some/file")
      expect(@commit.import_errors_in_redis).to eql([["StandardError", "This is a fake error (in /path/to/some/file)"]])
    end
  end

  context "#clear_import_errors!" do
    it "should clear all import errors of a commit in redis and postgres" do
      @commit.add_import_error_in_redis(StandardError.new("first fake error"))
      @commit.add_import_error_in_redis(StandardError.new("second fake error"), "in /path/to/some/file")
      @commit.update_attributes(import_errors: [["StandardError", "first fake error"], ["StandardError", "second fake error (in /path/to/some/file)"]])
      expect(@commit.import_errors_in_redis).to eql([["StandardError", "first fake error"], ["StandardError", "second fake error (in /path/to/some/file)"]])
      expect(@commit.import_errors).to eql([["StandardError", "first fake error"], ["StandardError", "second fake error (in /path/to/some/file)"]])

      @commit.clear_import_errors!
      expect(@commit.import_errors_in_redis).to eql([])
      expect(@commit.import_errors).to eql([])
    end
  end

  context "#move_import_errors_from_redis_to_sql_db!" do
    it "should move import errors from redis to sql db" do
      @commit.save
      @commit.add_import_error_in_redis(StandardError.new("this is a fake error"))
      expect(@commit.import_errors).to be_empty
      expect(@commit.import_errors_in_redis).to eql([["StandardError", "this is a fake error"]])
      @commit.move_import_errors_from_redis_to_sql_db!
      expect(@commit.reload.import_errors).to eql([["StandardError", "this is a fake error"]])
      expect(@commit.import_errors_in_redis).to be_empty
    end
  end

  context "clear_import_errors_in_redis" do
    it "should clear all import errors of a commit in redis" do
      @commit.add_import_error_in_redis(StandardError.new("first error"))
      @commit.add_import_error_in_redis(StandardError.new("second error"), "path/to/second/file")
      expect(@commit.import_errors_in_redis.length).to eql(2)
      @commit.send(:clear_import_errors_in_redis)
      expect(@commit.import_errors_in_redis).to eql([])
    end
  end

  context "#import_errors_redis_key" do
    it "should return the correct redis key" do
      expect(@commit.send(:import_errors_redis_key)).to eql("commit:#{@commit.revision}:import_errors")
    end
  end
end
