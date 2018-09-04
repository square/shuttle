require 'rails_helper'

RSpec.describe TmxBuilder do
  let(:expected_output) do
    %q(
<tmx version="1.4">
  <header datatype="PlainText">
    <generatedAt>12345</generatedAt>
  </header>
  <body>
    <tu tuid="this-is-a-project.this-is-a-tu">
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
    let!(:project) { FactoryBot.create(:project, repository_url: 'i-am-a-git-project.com', name: 'this-is-a-project') }
    let!(:commit) { FactoryBot.create(:commit, project: project) }
    let!(:key) { FactoryBot.create(:key, project: project, original_key: 'this-is-a-tu') }
    let!(:translationa) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 en. sentence 2 en.', rfc5646_locale: 'en-US') }
    let!(:translationb) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 es. sentence 2 es.', rfc5646_locale: 'es-US') }
    let!(:translationc) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 fr. sentence 2 fr. sentence 3 fr.', rfc5646_locale: 'fr-CA') }
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
    let!(:project) { FactoryBot.create(:project, repository_url: nil, name: 'this-is-a-project', job_type: :article) }
    let!(:article) { FactoryBot.create(:article, project: project, name: 'this-is-a-tu') }
    let!(:section) { FactoryBot.create(:section, article: article) }
    let!(:key) { FactoryBot.create(:key, section: section, original_key: 'this-is-a-tu') }
    let!(:translationa) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 en. sentence 2 en.', rfc5646_locale: 'en-US') }
    let!(:translationb) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 es. sentence 2 es.', rfc5646_locale: 'es-US') }
    let!(:translationc) { FactoryBot.create(:translation, key: key, copy: 'sentence 1 fr. sentence 2 fr. sentence 3 fr.', rfc5646_locale: 'fr-CA') }
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
