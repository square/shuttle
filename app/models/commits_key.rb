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

# A `has_and_belongs_to_many` join table between {Commit} and {Key} that has
# been upgraded to a full model class.

class CommitsKey < ActiveRecord::Base
  belongs_to :commit, inverse_of: :commits_keys
  belongs_to :key, inverse_of: :commits_keys
end
