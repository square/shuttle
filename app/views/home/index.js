// Copyright 2013 Square Inc.
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

$(window).ready(function() {
  $('.translate-link').click(function() {
    if ($(this).hasClass('disabled')) return false;

    var sha = $(this).data('sha');
    var project = $(this).data('project');
    var localeField =  $('#translate-link-locale-' + sha);
    var locale = localeField.val();

    var url = '/locales/' + encodeURIComponent(locale) + '/projects/' + encodeURIComponent(project) + '?commit=' + sha;
    window.location = url;

    return false;
  });

  $('.translate-link-locale').keydown(function() {
    if (($(this).val()).length > 0) $($(this).data('target')).removeClass('disabled');
    else $($(this).data('target')).addClass('disabled');
    return true;
  });

  new SmartForm($('#new_commit'), function() { window.location.reload(); });
  $('#new_commit_project_id').change(function() {
    var project = $(this).val();
    $('#new_commit').attr('action', '/projects/' + project + '/commits.json');
  });

  $('.show-request-translation-form-link').click(function(e){
    $(this).hide();
    $('.request-translation-form').slideDown();
    e.preventDefault();
  });

  $('.edit_commit select').change(function() {
    var select = $(this);
    var form = select.closest('form');
    var authParam = $('meta[name=csrf-param]').attr('content');
    var authToken = $('meta[name=csrf-token]').attr('content');
    var data = form.serializeObject();
    data[authParam] = authToken;

    $.ajax(form.attr('action'), {
      data: data,
      type: 'PATCH',
      success: function() {
        var checkmark = $('<i/>').addClass('icon-ok priority-change-success').appendTo(form);
        checkmark.oneTime(3000, function() {
          checkmark.fadeOut(function() { checkmark.remove(); });
        });
      },
      error: function() {
        alert("Couldn't change commit priority.");
      }
    });
  });

  $('.more-link').click(function() {
    var newContent = $(this).data('description');
    $(this).parent().text(newContent);
    return false;
  });
});
