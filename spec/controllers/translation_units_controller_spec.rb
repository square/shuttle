require 'spec_helper'

describe TranslationUnitsController do
  describe "#index" do
    before(:all) do
      @trans_units_list = FactoryGirl.create_list(:translation_unit, 51)
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      sign_in @user
    end

    it "loads only 50 translation units per page" do
      get :index
      response.status.should eql(200)
      assigns(:offset).should eql(0)
      assigns(:previous).should be_false
      assigns(:next).should be_true
      assigns(:translation_units).to_a.should eql(@trans_units_list[0,50])
    end

    it "renders the first page of results if passed offset < 0" do
      get :index, offset: -1
      response.status.should eql(200)
      assigns(:offset).should eql(0)
      assigns(:previous).should be_false
      assigns(:next).should be_true
      assigns(:translation_units).to_a.should eql(@trans_units_list[0,50])
    end

    it "correctly lists the last page of results" do
      get :index, offset: 50
      response.status.should eql(200)
      assigns(:offset).should eql(50)
      assigns(:previous).should be_true
      assigns(:next).should be_false
      assigns(:translation_units).to_a.should eql(@trans_units_list[50,51])
    end
  end
end
