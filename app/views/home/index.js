$(window).ready(function() {
  $('.translate-link').click(function() {
    var sha = $(this).data('sha');
    var project = $(this).data('project');
    var localeField =  $('#translate-link-locale-' + sha);
    var locale = localeField.val();

    var url = '/locales/' + encodeURIComponent(locale) + '/projects/' + encodeURIComponent(project) + '?commit=' + sha;
    window.location = url;

    return false;
  });

  new SmartForm($('#new_commit'), function() { window.location.reload(); });
  $('#new_commit_project_id').change(function() {
    var project = $(this).val();
    $('#new_commit').attr('action', '/projects/' + project + '/commits.json');
  });
});
