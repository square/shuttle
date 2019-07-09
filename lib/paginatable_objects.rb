# Copyright 2016 Square Inc.
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

class PaginatableObjects

  attr_reader :objects, :total_count, :current_page, :limit_value
  delegate :map, :each, :first, :length, :size, :sort_by, to: :objects

  def initialize(objects, current_page, limit_value)
    @objects = objects.objects
    @total_count = objects.total
    @current_page = current_page
    @limit_value = limit_value
  end

  def offset_value
    (@current_page - 1) * @limit_value
  end

  def total_pages
    ((total_count - 1) / limit_value) + 1
  end

  def last_page?
    current_page == total_pages
  end
end
