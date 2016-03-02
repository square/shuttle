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

# Regex for parsing blocks

class BlockPatterns
  # HTML block tags
  BLOCK_LEVEL_TAGS = %w(address article aside blockquote body caption dd div dl footer h1 h2 h3 h4 h5 h6 head header html li ol p section table tbody td tfoot th thead tr ul)

  # Matches start and end block tags, including any tag attributes
  BLOCK_TAG_REGEX   = /\A(#{BLOCK_LEVEL_TAGS.map { |tag| '<\/?' + tag + '[^>]*?>' }.join('|')})\Z/

  # Matches both block tags and block contents (as separate tokens)
  BLOCK_SPLIT_REGEX = /#{BLOCK_LEVEL_TAGS.map { |tag| '(\s*<\/?' + tag + '[^>]*?>\s*)' }.join('|')}/m
end
