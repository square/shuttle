
require 'spec_helper'

describe Importer::NtErb do
  describe "#import_file?" do
    it "should only import ERb files" do
      @project = FactoryGirl.create(:project)
      expect(Importer::NtErb.new(FactoryGirl.create(:fake_blob, project: @project), 'somewhere/DNE.erb').send(:import_file?)).to eq(true)
      expect(Importer::NtErb.new(FactoryGirl.create(:fake_blob, project: @project), 'somewhere/DNE.rb').send(:import_file?)).to eq(false)
    end
  end

  describe "[importing]" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(config/locales/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(nt_erb))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from .erb files" do
      pending "on updating spec/fixtures/repository.git to have files that call NT"
    end
  end
end
