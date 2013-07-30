require 'spec_helper'

describe TranslationUnitsController do
  describe "#index" do
    it "should not allow a non-reviewer" do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in FactoryGirl.create(:user, role: 'translator')
      get :index
      response.should be_redirect
    end

    context "[pagination]" do
      before :all do
        TranslationUnit.delete_all
        @trans_units_list = FactoryGirl.create_list(:translation_unit, 51, copy: 'foo').sort_by!(&:id).reverse!
        @user             = FactoryGirl.create(:user, role: 'reviewer')
      end

      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in @user
      end

      it "loads only 50 translation units per page" do
        get :index, keyword: 'foo', field: 'searchable_copy', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@trans_units_list[0, 50].map(&:id))
      end

      it "renders the first page of results if passed offset < 0" do
        get :index, keyword: 'foo', field: 'searchable_copy', offset: -1, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@trans_units_list[0, 50].map(&:id))
      end

      it "correctly lists the last page of results" do
        get :index, keyword: 'foo', field: 'searchable_copy', offset: 50, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@trans_units_list[50, 51].map(&:id))
      end
    end

    context "[filtering]" do
      before :all do
        TranslationUnit.delete_all
        @tus_source_foo = 5.times.map { |i| FactoryGirl.create(:translation_unit, source_copy: "foo #{i}", copy: "baz #{i}", rfc5646_locale: 'fr') }.sort_by!(&:id).reverse!
        @tus_source_bar = 5.times.map { |i| FactoryGirl.create(:translation_unit, source_copy: "bar #{i}", copy: "baz #{i}", rfc5646_locale: 'ja') }.sort_by!(&:id).reverse!
        @tus_target_foo = 5.times.map { |i| FactoryGirl.create(:translation_unit, source_copy: "baz #{i}", copy: "foo #{i}", rfc5646_locale: 'fr') }.sort_by!(&:id).reverse!
        @tus_target_bar = 5.times.map { |i| FactoryGirl.create(:translation_unit, source_copy: "baz #{i}", copy: "bar #{i}", rfc5646_locale: 'ja') }.sort_by!(&:id).reverse!
        @user           = FactoryGirl.create(:user, role: 'reviewer')
      end

      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in @user
      end

      it "should filter by source copy" do
        get :index, keyword: 'foo', field: 'searchable_source_copy', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@tus_source_foo.map(&:id))
      end

      it "should filter by target copy" do
        get :index, keyword: 'foo', field: 'searchable_copy', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@tus_target_foo.map(&:id))
      end

      it "should filter by target locale" do
        get :index, keyword: 'baz', field: 'searchable_source_copy', target_locales: 'fr', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['id'] }.should eql(@tus_target_foo.map(&:id))
      end
    end
  end

  describe "#edit" do
    it "should not allow a non-reviewer" do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in FactoryGirl.create(:user, role: 'translator')
      get :edit, id: FactoryGirl.create(:translation_unit).id
      response.should be_redirect
    end

    context "[authenticated user]" do
      before :all do
        @user = FactoryGirl.create(:user, role: 'reviewer')
      end

      before :each do
        @tu                            = FactoryGirl.create(:translation_unit)
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in @user
      end

      it "should render a page where the user can edit a translation unit" do
        get :edit, id: @tu.id
        response.status.should eql(200)
        response.should render_template('edit')
      end

      it "should respond with a 404 if the translation unit doesn't exist" do
        get :edit, id: TranslationUnit.maximum(:id) + 1
        response.status.should eql(404)
      end
    end
  end

  describe "#update" do
    it "should not allow a non-reviewer" do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in FactoryGirl.create(:user, role: 'translator')
      put :update,
          id:               FactoryGirl.create(:translation_unit).id,
          translation_unit: {copy: 'new'}
      response.should be_redirect
    end

    context "[authenticated user]" do
      before :all do
        @user = FactoryGirl.create(:user, role: 'reviewer')
      end

      before :each do
        @tu                            = FactoryGirl.create(:translation_unit)
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in @user
      end

      it "should update a translation unit with the given attributes" do
        put :update,
            id:               @tu.id,
            translation_unit: {copy: 'new'}
        response.should redirect_to(translation_units_url)
        @tu.reload.copy.should eql('new')
      end

      it "should respond with a 404 if the translation unit doesn't exist" do
        put :update,
            id:               TranslationUnit.maximum(:id) + 1,
            translation_unit: {copy: 'new'}
        response.status.should eql(404)
      end

      it "should respond with an error page if an invalid parameter value is provided" do
        pending "No possible error values"
      end

      it "should respond with a 400 if a protected parameter is provided" do
        put :update,
            id:               @tu.id,
            translation_unit: {source_copy: 'hello'}
        response.should_not be_success
        -> { @tu.reload }.should_not change(@tu, :source_copy)
      end
    end
  end

  describe "#destroy" do
    it "should not allow a non-reviewer" do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in FactoryGirl.create(:user, role: 'translator')
      delete :destroy, id: FactoryGirl.create(:translation_unit).id
      response.should be_redirect
    end

    context "[authenticated user]" do
      before :all do
        @user = FactoryGirl.create(:user, role: 'reviewer')
      end

      before :each do
        @tu                            = FactoryGirl.create(:translation_unit)
        @request.env['devise.mapping'] = Devise.mappings[:user]
        sign_in @user
      end

      it "should delete a translation unit" do
        delete :destroy, id: @tu.id
        response.should redirect_to(translation_units_url)
        -> { @tu.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "should respond with a 404 if the translation unit doesn't exist" do
        delete :destroy, id: TranslationUnit.maximum(:id) + 1
        response.status.should eql(404)
      end
    end
  end
end
