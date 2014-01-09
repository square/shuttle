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

describe TranslationDiff do
  describe "#context_ranges" do
    subject { TranslationDiff.new("", "").context_ranges(changes, @context) }

    context "should give nothing with empty changes" do
      let(:changes) { [] }
      it "with context 0" do
        @context = 0 ; expect(subject).to eq([])
      end
      it "with context 1" do
        @context = 1 ; expect(subject).to eq([])
      end
    end

    context "should give no ranges with no differences" do
      let(:changes) { [false, false, false] }
      it "with context 0" do
        @context = 0 ; expect(subject).to eq([])
      end
      it "with context 1" do
        @context = 1 ; expect(subject).to eq([])
      end
      it "with context 2" do
        @context = 2 ; expect(subject).to eq([])
      end
    end

    context "should recognize a single truth" do
      let(:changes) { [true] }
      it "with context 0" do
        @context = 0 ; expect(subject).to eq([0..0])
      end
      it "with context 1" do
        @context = 1 ; expect(subject).to eq([0..0])
      end
    end

    context "should deal with truths at borders" do
      context do
        let(:changes) { [true, false, false, false, false, true] }
        it "with context 0" do
          @context = 0 ; expect(subject).to eq([0..0, 5..5])
        end
        it "with context beyond the borders" do
          @context = 1 ; expect(subject).to eq([0..1, 4..5])
        end
      end
    end

    context "should deal with truths close to borders" do
      let(:changes) { [false, true, false, false, false] }
      it "with a buffer from the borders" do
        @context = 0 ; expect(subject).to eq([1..1])
      end
      it "touching the border to the left" do
        @context = 1 ; expect(subject).to eq([0..2])
      end
      it "beyond the border to the left" do
        @context = 2 ; expect(subject).to eq([0..3])
      end
    end

    context "should deal with truths in the middle" do
      let(:changes) { [false, false, true, false, false] }
      it "within bounds of array" do
        @context = 1 ; expect(subject).to eq([1..3])
      end
      it "touching bounds of array" do
        @context = 2 ; expect(subject).to eq([0..4])
      end
    end

    context "should deal with adjacent truths" do
      let(:changes) { [false, false, true, true, false, false] }
      it "with context 0" do
        @context = 0 ; expect(subject).to eq([2..3])
      end
      it "at the end of context" do
        @context = 1 ; expect(subject).to eq([1..4])
      end
      it "within bound of context" do
        @context = 2 ; expect(subject).to eq([0..5])
      end
    end

    context "should deal with overlapping contexts" do
      let(:changes) { [false, false, true, false, true, false, false] }
      it "with falses overlapping" do
        @context = 1 ; expect(subject).to eq([1..5])
      end
      it "with truth being overlapped" do
        @context = 2 ; expect(subject).to eq([0..6])
      end
    end

    context "should deal with touching contexts" do
      let(:changes) { [false, false, true, false, false, true, false, false] }
      it { @context = 1 ; expect(subject).to eq([1..6]) }
    end
  end

  describe "#diff" do
    subject { TranslationDiff.new(one, two).diff }

    context "with empty strings" do
      let(:one) { "" }
      let(:two) { "" }
      it "should not crash" do
        expect(subject).to eq(["", ""])
      end
    end

    context "should deal with a single empty string" do
      let(:one) { "A non-empty string" }
      let(:two) { "" }
      it { expect(subject[0]).to eq(one) }
    end

    context "with a single word that changes" do
      let(:one) { "one" }
      let(:two) { "two" }
      it "should just display the change" do
        expect(subject).to eq(["one", "two"])
      end
    end

    context "with additional content" do
      let(:one) { "one plus" }
      let(:two) { "two" }
      it "should pad with space" do
        expect(subject).to eq(["one plus", "two     "])
      end
    end

    context "with changes on one end" do
      let(:one) { "one is the very same" }
      let(:two) { "two is the very same" }
      it "should format with ellipses" do
        expect(subject).to eq(["one is...", "two is..."])
      end
    end
    context "with changes on both ends" do
      let(:one) { "one is the very same" }
      let(:two) { "two is the very some" }
      it "should format with ellipses" do
        expect(subject).to eq(["one is...very same", "two is...very some"])
      end
    end

    context "with single change in middle" do
      let(:one) { "This is one in the middle" }
      let(:two) { "This is two in the middle" }
      it "it should properly format with ellipses" do
        one = "This is one in the middle"
        two = "This is two in the middle"
        expect(subject).to eq(["...is one in...", "...is two in..."])
      end
    end

    context "with different-sized words" do
      let(:one) { "This is three with stuff" }
      let(:two) { "This is two with stuff" }
      it "should pad with spaces" do
        expect(subject).to eq(["...is three with...", "...is  two  with..."])
      end
    end

    context "with extra spaces in the sentences" do
      let(:one) { "This is  one with space" }
      let(:two) { "This is one  with space" }
      it "should ignore the extra spaces" do
        expect(subject).to eq(["", ""])
      end
    end
  end
end
