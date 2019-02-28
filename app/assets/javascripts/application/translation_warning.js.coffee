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

root = exports ? this

# Characters to warn translators about. A list of four items:
#
# 1. an identifier for the character (used in CSS class names),
# 2. the bad character,
# 3. the human name of the bad character,
# 4. the suggested replacement character, and
# 5. the human name for the replacement character.
#
root.TRANSLATION_WARNING_CHARACTERS = [
  ['dash', '--', 'a double dash', '—', 'an em-dash'],
  ['double', '"', 'dumb quotes', '“”', 'smart quotes'],
  ['single', "'", 'dumb quotes', '‘’', 'smart quotes'],
  ['smiley', ':)', 'ASCII smiley', '☺', 'super cool Unicode smiley']
]

# Prepare the translation warning messages.
# The translation warning messages are inserted into their container with hidden state.
root.prepareTranslationWarning = (warningContainer) ->
  for chars in TRANSLATION_WARNING_CHARACTERS
    $('<p/>').addClass("warning dumb-#{chars[0]}")
      .text("Consider using #{chars[4]} #{chars[3]} instead of #{chars[2]} #{chars[1]}.")
      .appendTo(warningContainer)
      .hide()

# Checks to show or hide translation warning messages.
root.checkTranslationWarning = (warningContainer, copy) ->
  if copy.length == 0
    for chars in TRANSLATION_WARNING_CHARACTERS
      warningContainer.find(".dumb-#{chars[0]}").hide()
    return

  for chars in TRANSLATION_WARNING_CHARACTERS
    if copy.indexOf(chars[1]) > -1
      warningContainer.find(".dumb-#{chars[0]}").show()
    else
      warningContainer.find(".dumb-#{chars[0]}").hide()
