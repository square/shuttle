require 'rails_helper'

RSpec.describe AssetsController, type: :controller do
  describe '#create' do
    before :each do
      @project = FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )

      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryBot.create(:user, :confirmed, role: 'monitor')
      sign_in @user
    end

    it "doesn't create a Asset without a name or file, shows the errors to user" do
      post :create, project_id: @project, asset: {name: ""}, format: :json
      expect(response.status).to eql(400)
      expect(Asset.count).to eql(0)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"name"=>["can’t be blank"], "file"=>["can’t be blank"], "file_name"=>["can’t be blank"]}}})
    end

    it "should associate the Asset with the current user" do
      post :create, project_id: @project, asset: FactoryBot.attributes_for(:asset), format: 'json'
      expect(@project.assets.first.user).to eql(@user)
    end

    it "creates an Asset that inherits locale settings from Project" do
      post :create, project_id: @project, asset: FactoryBot.attributes_for(:asset, name: 'foo'), format: :json
      expect(response.status).to eql(200)
      expect(Asset.count).to eql(1)
      asset = Asset.last
      expect(asset.base_rfc5646_locale).to eql('en')
      expect(asset.targeted_rfc5646_locales).to eql({ 'fr' => true, 'es' => false })
      expect(asset.base_locale).to eql(Locale.from_rfc5646('en'))
      expect(asset.targeted_locales.map(&:rfc5646)).to match_array(%w(es fr))
    end

    it "creates an Asset that has its own locale settings different from those of Project's" do
      post :create, project_id: @project, asset: FactoryBot.attributes_for(:asset, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: { 'ja' => true }), format: :json
      expect(response.status).to eql(200)
      expect(Asset.count).to eql(1)
      asset = Asset.last
      expect(asset.base_rfc5646_locale).to eql('en-US')
      expect(asset.targeted_rfc5646_locales).to eql({ 'ja' => true })
      expect(asset.base_locale).to eql(Locale.from_rfc5646('en-US'))
      expect(asset.targeted_locales.map(&:rfc5646)).to eql(%w(ja))
    end

    it "doesn't create a Asset in a Project with a duplicate key name" do
      FactoryBot.create(:asset, project: @project, name: 'foo')
      post :create, project_id: @project, asset: FactoryBot.attributes_for(:asset, name: 'foo'), format: :json
      expect(response.status).to eql(400)
      expect(Asset.count).to eql(1)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"name"=>["already taken"]}}})
    end
  end

  describe 'show/hide' do
    before :each do
      @project = FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
    end

    let(:monitor_user) { FactoryBot.create(:user, :confirmed, role: 'monitor') }
    let(:reviewer_user) { FactoryBot.create(:user, :confirmed, role: 'reviewer') }

    def sign_in_monitor_user
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in monitor_user
    end

    def sign_in_reviewer_user
      request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in reviewer_user
    end

    describe "#hide_in_dashboard" do
      before(:each) do
        @asset = FactoryBot.create(:asset, project: @project, name: "asset 1", hidden: false)
      end

      it "should not allow monitor user to hide asset" do
        sign_in_monitor_user
        patch :hide_in_dashboard, project_id: @project, id: @asset
        expect(response.status).to eql(302)
        @asset.reload
        expect(@asset.hidden).to be false
      end

      it "should allow reviewer user to hide asset" do
        sign_in_reviewer_user
        patch :hide_in_dashboard, project_id: @project, id: @asset
        expect(response.status).to eql(302)
        @asset.reload
        expect(@asset.hidden).to be true
      end
    end

    describe "#show_in_dashboard" do
      before(:each) do
        @asset = FactoryBot.create(:asset, project: @project, name: "asset 1", hidden: true)
      end

      it "should not allow monitor user to re-open hidden asset" do
        sign_in_monitor_user
        patch :show_in_dashboard, project_id: @project, id: @asset
        expect(response.status).to eql(302)
        @asset.reload
        expect(@asset.hidden).to be true
      end

      it "should allow reviewer user to re-open hidden asset" do
        sign_in_reviewer_user
        patch :show_in_dashboard, project_id: @project, id: @asset
        expect(response.status).to eql(302)
        @asset.reload
        expect(@asset.hidden).to be false
      end
    end
  end
end
