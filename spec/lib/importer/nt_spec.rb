
require 'spec_helper'

describe Importer::NtBase do
  before :each do
    Key.delete_all
    Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
    @project = FactoryGirl.create(:project,
                                  repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                  targeted_rfc5646_locales: {'en-US' => true, 'es' => true})
    @commit = @project.commit!('HEAD', skip_import: true)
    @blob = FactoryGirl.create(:blob,
                               project: @project
                              )
  end

  describe "#add_nt_string" do
    it "should add keys for blobs" do
      importer = Importer::Base.new(@blob, "DNE.text", @commit)
      importer.class.send(:include, Importer::NtBase)
      importer.instance_variable_set(:@keys, Set.new)

      importer.add_nt_string("A string to translate", "The context for the string")
      expect(Key.count).to eq(1)
      key = Key.first
      expect(key.source_copy).to eq("A string to translate")
      expect(key.context).to eq("The context for the string")

      expect(key.translations.count).to eq(1)
    end
  end
end
