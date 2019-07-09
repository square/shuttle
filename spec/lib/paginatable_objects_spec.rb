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
    FactoryBot.create_list :commit, 10, project: project
    CommitsIndex.reset!
    @es_objects = CommitsIndex.filter(term: {project_id: project.id})
  end

  describe '#offset_value' do
    it 'finds the correct offset_value' do
      expect(PaginatableObjects.new(@es_objects, 1, 5).offset_value).to eql(0)
      expect(PaginatableObjects.new(@es_objects, 2, 5).offset_value).to eql(5)
      expect(PaginatableObjects.new(@es_objects, 3, 5).offset_value).to eql(10)
    end
  end

  describe '#total_pages' do
    it 'returns the total number of pages' do
      expect(PaginatableObjects.new(@es_objects, 1, 4).total_pages).to eql(3)
      expect(PaginatableObjects.new(@es_objects, 1, 5).total_pages).to eql(2)
      expect(PaginatableObjects.new(@es_objects, 1, 6).total_pages).to eql(2)
    end
  end

  describe '#last_page?' do
    it 'returns true if last page' do
      expect(PaginatableObjects.new(@es_objects, 3, 4).last_page?).to be_truthy
    end

    it 'returns false if not page' do
      expect(PaginatableObjects.new(@es_objects, 1, 4).last_page?).to be_falsey
      expect(PaginatableObjects.new(@es_objects, 2, 4).last_page?).to be_falsey
    end
  end
end
