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
require 'rake'

describe 'autotranslate:en_gb' do
  subject { Rake::Task['autotranslate:en_gb'].invoke }

  before :all do
    Rake.application.rake_require "tasks/autotranslate"
    Rake::Task.define_task(:environment)
  end

  it 'autotranslates untranslated en-GB translations' do
    en_gb_translation = FactoryGirl.create(:translation, rfc5646_locale: 'en-GB', source_copy: 'The color of love', copy: nil)
    en_ca_translation = FactoryGirl.create(:translation, rfc5646_locale: 'en-CA', copy: nil)

    subject

    expect(en_gb_translation.reload.copy).to eq('The colour of love')
    expect(en_gb_translation.reload.translated).to be_truthy
    expect(en_ca_translation.reload.translated).to be_falsey
  end
end
