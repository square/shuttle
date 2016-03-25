require 'spec_helper'

describe CommitsSearchPresenter do
  let!(:project) do
    FactoryGirl.create(:project,
                       base_rfc5646_locale:      'en',
                       targeted_rfc5646_locales: {'fr' => true, 'es' => true, 'es-US' => true,
                                                  'en-GB' => true, 'en-US' => false, 'ja' => false},
                       repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
  end

  describe '#locales_to_show' do
    it 'should select base locale plus up to four other required locales if no locales specified' do
      presenter = CommitsSearchPresenter.new(nil, true, project)
      to_show = presenter.locales_to_show
      expected = Hash[['en', 'fr', 'es', 'es-US', 'en-GB'].map { |l| [Locale.from_rfc5646(l), true] }]
      expect(to_show).to eql expected
    end

    it 'should select the base locale plus up to four of the requested locales' do
      locales = [' fr', 'en-US', 'ja   ', 'en-GB']
      presenter = CommitsSearchPresenter.new(locales, true, project)
      to_show = presenter.locales_to_show
      expected = {
          Locale.from_rfc5646('en') => true,
          Locale.from_rfc5646('fr') => true,
          Locale.from_rfc5646('en-US') => false,
          Locale.from_rfc5646('ja') => false,
          Locale.from_rfc5646('en-GB') => true,
      }
      expect(to_show).to eql expected
      expect(to_show.keys).to eql expected.keys

      locales = [' fr', 'en-US', 'ja   ', 'en-GB', 'es-US']
      presenter = CommitsSearchPresenter.new(locales, true, project)
      to_show = presenter.locales_to_show
      expected = {
          Locale.from_rfc5646('en') => true,
          Locale.from_rfc5646('fr') => true,
          Locale.from_rfc5646('en-US') => false,
          Locale.from_rfc5646('ja') => false,
          Locale.from_rfc5646('en-GB') => true,
      }
      expect(to_show).to eql expected
      expect(to_show.keys).to eql expected.keys
    end
  end

  describe '#translation_text' do
    it 'should have expected translations text when copy is empty' do
      translation = FactoryGirl.create(:translation, copy: "")
      presenter = CommitsSearchPresenter.new(nil, true, project)
      expect(presenter.translation_text(translation)).to eql "(empty string)"
    end

    it 'should have expected translations text when copy is just whitespace' do
      translation = FactoryGirl.create(:translation, copy: "  ")
      presenter = CommitsSearchPresenter.new(nil, true, project)
      expect(presenter.translation_text(translation)).to eql "(2 whitespace string)"
    end

    it 'should have expected translations text when copy has content with length less than 31 characters' do
      translation = FactoryGirl.create(:translation, copy: "test string")
      presenter = CommitsSearchPresenter.new(nil, true, project)
      expect(presenter.translation_text(translation)).to eql "test string"
    end

    it 'should have expected translations text when copy has content with length more than 31 characters' do
      translation = FactoryGirl.create(:translation, copy: ("a" * 35))
      presenter = CommitsSearchPresenter.new(nil, true, project)
      expect(presenter.translation_text(translation)).to eql "a" * 31
    end
  end
end

