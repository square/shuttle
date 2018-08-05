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

require "rails_helper"

RSpec.describe LocaleAssociationsController do
  describe "routing" do

    it "routes to #index" do
      expect(get("/locale_associations")).to route_to("locale_associations#index")
    end

    it "routes to #new" do
      expect(get("/locale_associations/new")).to route_to("locale_associations#new")
    end

    it "routes to #edit" do
      expect(get("/locale_associations/1/edit")).to route_to("locale_associations#edit", :id => "1")
    end

    it "routes to #create" do
      expect(post("/locale_associations")).to route_to("locale_associations#create")
    end

    it "routes to #update" do
      expect(put("/locale_associations/1")).to route_to("locale_associations#update", :id => "1")
    end

    it "routes to #destroy" do
      expect(delete("/locale_associations/1")).to route_to("locale_associations#destroy", :id => "1")
    end

  end
end
