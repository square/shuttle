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

# This observer on the {Translation} model...
#
# 1. Creates a {TranslationChange} if a {Translation} is changed
# 2. Updates Translation Memory if a translator is updating the {Translation}

class TranslationObserver < ActiveRecord::Observer
  # TODO (yunus): move to after_commit_on_update
  def after_update(translation)
    log_change(translation)
  end

  def after_commit_on_update(translation)
    update_translation_memory(translation)
  end

  private
  def log_change(translation)
    TranslationChange.create_from_translation!(translation)
  end

  # Update the Translation memory if a human is updating it.
  def update_translation_memory(translation)
    TranslationUnit.store(translation) if translation.modifier
  end
end
