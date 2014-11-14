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

describe LocaleAssociationsController do

  # This should return the minimal set of attributes required to create a valid
  # LocaleAssociation. As you add validations to LocaleAssociation, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "source_rfc5646_locale" => "fr", "target_rfc5646_locale" => "fr-CA", "checked" => "0", "uncheck_disabled" => "0" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # LocaleAssociationsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  before :each do
    user = FactoryGirl.create(:user, :confirmed, role: 'translator')
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
  end

  describe "GET index" do
    it "assigns all locale_associations as @locale_associations" do
      locale_association = LocaleAssociation.create! valid_attributes
      get :index, {}, valid_session
      assigns(:locale_associations).should eq([locale_association])
    end
  end

  describe "GET new" do
    it "assigns a new locale_association as @locale_association" do
      get :new, {}, valid_session
      assigns(:locale_association).should be_a_new(LocaleAssociation)
    end
  end

  describe "GET edit" do
    it "assigns the requested locale_association as @locale_association" do
      locale_association = LocaleAssociation.create! valid_attributes
      get :edit, {:id => locale_association.to_param}, valid_session
      assigns(:locale_association).should eq(locale_association)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new LocaleAssociation" do
        expect {
          post :create, {:locale_association => valid_attributes}, valid_session
        }.to change(LocaleAssociation, :count).by(1)
      end

      it "assigns a newly created locale_association as @locale_association" do
        post :create, {:locale_association => valid_attributes}, valid_session
        assigns(:locale_association).should be_a(LocaleAssociation)
        assigns(:locale_association).should be_persisted
      end

      it "redirects to the created locale_association edit page" do
        post :create, {:locale_association => valid_attributes}, valid_session
        response.should redirect_to(edit_locale_association_url(LocaleAssociation.last))
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved locale_association as @locale_association" do
        # Trigger the behavior that occurs when invalid params are submitted
        LocaleAssociation.any_instance.stub(:save).and_return(false)
        post :create, {:locale_association => { "source_rfc5646_locale" => "invalid value" }}, valid_session
        assigns(:locale_association).should be_a_new(LocaleAssociation)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        LocaleAssociation.any_instance.stub(:save).and_return(false)
        post :create, {:locale_association => { "source_rfc5646_locale" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested locale_association" do
        locale_association = LocaleAssociation.create! valid_attributes
        # Assuming there are no other locale_associations in the database, this
        # specifies that the LocaleAssociation created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        LocaleAssociation.any_instance.should_receive(:update).with({ "source_rfc5646_locale" => "MyString" })
        put :update, {:id => locale_association.to_param, :locale_association => { "source_rfc5646_locale" => "MyString" }}, valid_session
      end

      it "assigns the requested locale_association as @locale_association" do
        locale_association = LocaleAssociation.create! valid_attributes
        put :update, {:id => locale_association.to_param, :locale_association => valid_attributes}, valid_session
        assigns(:locale_association).should eq(locale_association)
      end

      it "redirects to the locale_association edit page" do
        locale_association = LocaleAssociation.create! valid_attributes
        put :update, {:id => locale_association.to_param, :locale_association => valid_attributes}, valid_session
        response.should redirect_to(edit_locale_association_url(locale_association))
      end
    end

    describe "with invalid params" do
      it "assigns the locale_association as @locale_association" do
        locale_association = LocaleAssociation.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        LocaleAssociation.any_instance.stub(:save).and_return(false)
        put :update, {:id => locale_association.to_param, :locale_association => { "source_rfc5646_locale" => "invalid value" }}, valid_session
        assigns(:locale_association).should eq(locale_association)
      end

      it "re-renders the 'edit' template" do
        locale_association = LocaleAssociation.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        LocaleAssociation.any_instance.stub(:save).and_return(false)
        put :update, {:id => locale_association.to_param, :locale_association => { "source_rfc5646_locale" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested locale_association" do
      locale_association = LocaleAssociation.create! valid_attributes
      expect {
        delete :destroy, {:id => locale_association.to_param}, valid_session
      }.to change(LocaleAssociation, :count).by(-1)
    end

    it "redirects to the locale_associations list" do
      locale_association = LocaleAssociation.create! valid_attributes
      delete :destroy, {:id => locale_association.to_param}, valid_session
      response.should redirect_to(locale_associations_url)
    end
  end

end
