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

describe BasicMediator do
  before :each do
    @mediator = BasicMediator.new
  end

  describe "#success?" do
    it "returns true if there are no errors" do
      expect(@mediator.success?).to eql(true)
    end

    it "returns false if there are any errors" do
      @mediator.send(:add_error, "Test")
      expect(@mediator.success?).to eql(false)
    end
  end

  describe "#failure?" do
    it "returns true if there are any errors" do
      @mediator.send(:add_error, "Test")
      expect(@mediator.failure?).to eql(true)
    end

    it "returns false if there are no errors" do
      expect(@mediator.failure?).to eql(false)
    end
  end

  describe "#add_error" do
    it "adds an error to mediator" do
      @mediator.send(:add_error, "Test1")
      @mediator.send(:add_error, "Test2")
      expect(@mediator.errors).to eql(["Test1", "Test2"])
    end
  end

  describe "#add_errors" do
    it "adds errors in bulk to mediator" do
      @mediator.send(:add_errors, ["Test1", "Test2"])
      @mediator.send(:add_errors, ["Test3", "Test4"])
      expect(@mediator.errors).to eql(["Test1", "Test2", "Test3", "Test4"])
    end
  end
end
