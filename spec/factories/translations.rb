# encoding: utf-8

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

FactoryGirl.define do
  factory :translation do
    association :key
    association :translator, factory: :user
    sequence(:source_copy) { |i| "#{i} men came to kill me one time. The best of 'em carried this. It's a Callahan full-bore autolock." }
    sequence(:copy) { |i| "#{i} Männer kamen mal, um mich zu töten. Der Beste von denen, hatte die bei sich. Es ist eine Callahan Vollkaliber mit Auto-Sicherung." }
    source_rfc5646_locale 'en-US'
    rfc5646_locale 'de-DE'
  end
end
