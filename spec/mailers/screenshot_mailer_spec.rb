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

require "spec_helper"

describe ScreenshotMailer do
  describe 'request_screenshot' do
    let(:translator)    { FactoryGirl.create(:user) }
    let(:developer)     { FactoryGirl.create(:user) }
    let(:author_email)  { 'author@example.com' }
    let(:commit)        { FactoryGirl.create(:commit, user: developer, author_email: author_email) }
    let(:mail)          { ScreenshotMailer.request_screenshot(commit, translator)}

    it 'renders the subject' do
      expect(mail.subject).to eql(I18n.t('mailer.screenshot.request_screenshot.subject', sha: commit.revision_prefix))
    end

    it 'should e-mail the requesting developer' do
      expect(mail.to).to include(developer.email)
    end

    it 'should e-mail the author' do
      expect(mail.to).to include(author_email)
    end

    it 'should cc the screenshot requester' do
      expect(mail.cc).to include(translator.email)
    end

    it 'should contain link to gallery page' do
      expect(mail.body).to include(gallery_project_commit_url(commit.project, commit))
    end
  end
end
