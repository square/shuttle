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

module Views
  module Translations
    module History
      def history_info
        if @translation.translation_changes.present?
          h2 "History"

          ul class: 'translation-change-history' do
            @translation.translation_changes.reverse.each do |change|
              li class: 'translation-change-entry' do
                div class: 'row-fluid' do
                  div class: 'span9' do
                    dl do
                      dt(
                        if change.user.present?
                          change.user.name
                        else
                          "(Automatic)"
                        end
                      )
                      if change.diff["copy"].present?
                        dd class: "copy-collapsed" do
                          change.compact_copy_from ? (code change.compact_copy_from) : (text "None")
                          text " to "
                          change.compact_copy_to ? (code change.compact_copy_to) : (text "None")
                        end
                        dd class: "copy-full" do
                          change.diff["copy"][0] ? (pre change.full_copy_from) : (div "None")
                          h5 " to "
                          change.diff["copy"][1] ? (pre change.full_copy_to) : (div "None")
                        end
                      end
                      if change.diff["approved"].present?
                        dd change.approval_transition
                      end
                    end
                  end
                  div class: 'span3' do
                    div change.created_at.strftime("%l:%M %P, %d %b %y"), class: "translation-change-timestamp"
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
