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

# Join table between {Article} and {Group}.
#
# Associations
# ------------
#
# |           |                                   |
# |:----------|:----------------------------------|
# | `article` | The {Article} found in the Group. |
# | `group`   | The {Group} with the Article.     |

# Represents the relationship between articles and their groups.
class ArticleGroup < ActiveRecord::Base
  belongs_to :group, inverse_of: :article_groups
  belongs_to :article, inverse_of: :article_groups
end
