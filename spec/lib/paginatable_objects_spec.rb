# Copyright 2016 Square Inc.
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

RSpec.describe PaginatableObjects do

  before do
    project = FactoryBot.create(:project)
    @commit1 = FactoryBot.create(:commit, project: project)
    @commit2 = FactoryBot.create(:commit, project: project)
    @commit3 = FactoryBot.create(:commit, project: project)
    @commit4 = FactoryBot.create(:commit, project: project)
    @commit5 = FactoryBot.create(:commit, project: project)

    @commits = [@commit1, @commit2, @commit3, @commit4, @commit5]
    @es_objects = [double('es_result', id: @commit4.id),
                   double('es_result', id: @commit1.id),
                   double('es_result', id: @commit5.id),
                   double('es_result', id: @commit2.id),
                   double('es_result', id: @commit3.id)]

    class << @es_objects
      def total() 10 end
    end
  end

  describe '#initialize' do
    it 'keeps objects sorted' do
      ordered_commits = PaginatableObjects.new(@commits, @es_objects, 1, 5).objects
      expect(ordered_commits).to eql([@commit4, @commit1, @commit5, @commit2, @commit3])
    end
  end

  describe '#offset_value' do
    it 'finds the correct offset_value' do
      expect(PaginatableObjects.new([], @es_objects, 1, 5).offset_value).to eql(0)
      expect(PaginatableObjects.new([], @es_objects, 2, 5).offset_value).to eql(5)
      expect(PaginatableObjects.new([], @es_objects, 3, 5).offset_value).to eql(10)
    end
  end

  describe '#total_pages' do
    it 'returns the total number of pages' do
      expect(PaginatableObjects.new([], @es_objects, 1, 4).total_pages).to eql(3)
      expect(PaginatableObjects.new([], @es_objects, 1, 5).total_pages).to eql(2)
      expect(PaginatableObjects.new([], @es_objects, 1, 6).total_pages).to eql(2)
    end
  end

  describe '#last_page?' do
    it 'returns true if last page' do
      expect(PaginatableObjects.new([], @es_objects, 3, 4).last_page?).to be_truthy
    end

    it 'returns false if not page' do
      expect(PaginatableObjects.new([], @es_objects, 1, 4).last_page?).to be_falsey
      expect(PaginatableObjects.new([], @es_objects, 2, 4).last_page?).to be_falsey
    end
  end
end
