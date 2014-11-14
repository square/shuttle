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
    # if this is the edit page for a locale association
    if $('body').attr('id') in ['locale_associations-new', 'locale_associations-edit', 'locale_associations-update']

        # When 'locale_association_checked' checkbox changes from 'checked' state to 'unchecked' state,
        # 'locale_association_uncheck_disabled' should also go to 'unchecked' state, because
        # disallowing unchecking of associated translations don't make sense if they are not
        # checked by default.
        # 'locale_association_uncheck_disabled' checkbox should also be disabled if 'checked'
        # is not 'set'.

        refreshCheckboxes = ->
            uncheckDisabledCheckbox = $('#locale_association_uncheck_disabled')
            uncheckDisabledControlGroup = uncheckDisabledCheckbox.closest('.control-group')
            if $('#locale_association_checked').is(":checked")
                uncheckDisabledControlGroup.removeClass('disabled')
                uncheckDisabledCheckbox.prop('disabled', false)
            else
                uncheckDisabledControlGroup.addClass('disabled')
                uncheckDisabledCheckbox.prop('disabled', true).prop('checked', false)

        refreshCheckboxes()
        $('#locale_association_checked').change ->
            refreshCheckboxes()
