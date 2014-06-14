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

$(document).ready ->
  # A simple hook that hooks 'data-scroll-to' attr to jquery-scrollTo plugin.
  $('[data-scroll-to]').click (event) ->
    $(window).scrollTo($(this).attr('data-scroll-to'), 300);
    # Cancel event
    event.preventDefault();
    event.stopImmediatePropagation();
    return false;
