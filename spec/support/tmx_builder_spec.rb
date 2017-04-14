require 'spec_helper'

describe TmxBuilder do
  let(:expected_output) do
    %q(
<tmx version="1.4">
  <header datatype="PlainText">
    <generatedAt>12345</generatedAt>
  </header>
  <body>
    <tu>
      <tuv xml:lang="en-US">
        <seg>sentence 1 en.</seg>
        <seg>sentence 2 en.</seg>
      </tuv>
      <tuv xml:lang="es-US">
        <seg>sentence 1 es.</seg>
        <seg>sentence 2 es.</seg>
      </tuv>
    </tu>
  </body>
</tmx>
    ).strip
  end

  context 'git project' do
    let!(:project) { FactoryGirl.create(:project, repository_url: 'i-am-a-git-project.com') }
    let!(:commit) { FactoryGirl.create(:commit, project: project) }
    let!(:key) { FactoryGirl.create(:key, project: project) }
    let!(:translationa) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 en. sentence 2 en.', rfc5646_locale: 'en-US') }
    let!(:translationb) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 es. sentence 2 es.', rfc5646_locale: 'es-US') }
    let!(:translationc) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 fr. sentence 2 fr. sentence 3 fr.', rfc5646_locale: 'fr-CA') }
    let!(:builder) { TmxBuilder.new(project) }

    before do
      CommitsKey.create(commit: commit, key: key)
      allow(Time.zone).to receive(:now).and_return 12345
    end

    describe '#build_tmx' do
      it 'generates a tmx file, discards tuvs with different seg counts' do
        expect(builder.tmx).to eq expected_output
      end
    end
  end

  context 'api project' do
    let!(:project) { FactoryGirl.create(:project, repository_url: nil) }
    let!(:article) { FactoryGirl.create(:article, project: project) }
    let!(:section) { FactoryGirl.create(:section, article: article) }
    let!(:key) { FactoryGirl.create(:key, section: section) }
    let!(:translationa) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 en. sentence 2 en.', rfc5646_locale: 'en-US') }
    let!(:translationb) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 es. sentence 2 es.', rfc5646_locale: 'es-US') }
    let!(:translationc) { FactoryGirl.create(:translation, key: key, copy: 'sentence 1 fr. sentence 2 fr. sentence 3 fr.', rfc5646_locale: 'fr-CA') }
    let!(:builder) { TmxBuilder.new(project) }

    before do
      allow(Time.zone).to receive(:now).and_return 12345
    end

    describe '#build_tmx' do
      it 'generates a tmx file, discards tuvs with different seg counts' do
        expect(builder.tmx).to eq expected_output
      end
    end
  end
end
