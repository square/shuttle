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

class Screenshot < ActiveRecord::Base
  belongs_to :commit, inverse_of: :screenshots

  CONTENT_TYPES = %w(image/jpg image/jpeg image/png image/gif)

  has_attached_file :image, {
    styles: { thumb: '400x200' }
  }

  validates_attachment :image,
                       presence: true,
                       content_type: { content_type: CONTENT_TYPES },
                       size: { less_than: 5.megabytes }
end
