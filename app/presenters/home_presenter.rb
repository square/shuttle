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

class HomePresenter

  include ActionView::Helpers::TextHelper

  def full_description(commit)
    commit.description || '-'
  end

  def short_description(commit)
    truncate(full_description(commit), length: 50)
  end

  def due_date_class(commit)
    if commit.due_date < 2.days.from_now.to_date
      'due-date-very-soon'
    elsif commit.due_date < 5.days.from_now.to_date
      'due-date-soon'
    else
      nil
    end
  end
end
