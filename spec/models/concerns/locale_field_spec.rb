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

describe LocaleField do
  it "should convert between an RFC 5646 code and a Locale" do
    t = FactoryGirl.build(:translation, rfc5646_locale: 'de-DE')
    expect(t.locale.rfc5646).to eql('de-DE')
    t.locale = Locale.from_rfc5646('fr-CA')
    expect(t.rfc5646_locale).to eql('fr-CA')
  end

  it "should use a custom reader and writer" do
    pr = FactoryGirl.build(:project, targeted_rfc5646_locales: {'de-DE' => true, 'fr-CA' => false})
    lr = pr.locale_requirements
    expect(lr.keys.sort_by(&:rfc5646)).to eql([Locale.from_rfc5646('de-DE'), Locale.from_rfc5646('fr-CA')])
    pr.locale_requirements = {
        Locale.from_rfc5646('en-US') => true,
        Locale.from_rfc5646('zh-HK') => false
    }
    expect(pr.targeted_rfc5646_locales).
        to eql(
                   'en-US' => true,
                   'zh-HK' => false
               )
  end

  it "should use a custom from column" do
    pr = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
    expect(pr.base_locale.rfc5646).to eql('en-US')
    pr.base_locale = Locale.from_rfc5646('zh-HK')
    expect(pr.base_rfc5646_locale).to eql('zh-HK')
  end
end
