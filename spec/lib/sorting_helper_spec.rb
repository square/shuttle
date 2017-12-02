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

RSpec.describe SortingHelper do
  describe "#order_by_elasticsearch_result_order" do
    before do
      project = FactoryBot.create(:project)
      @commit1 = FactoryBot.create(:commit, project: project)
      @commit2 = FactoryBot.create(:commit, project: project)
      @commit3 = FactoryBot.create(:commit, project: project)

      @commits = [@commit1, @commit2, @commit3]
      @es_objects = [double('es_result', id: @commit2.id),
                     double('es_result', id: @commit3.id),
                     double('es_result', id: @commit1.id)]
    end

    it "orders items with the elasticsearch results order" do
      ordered_commits = SortingHelper.order_by_elasticsearch_result_order(@commits, @es_objects)

      expect(ordered_commits).to eql([@commit2, @commit3, @commit1])
    end
  end
end
