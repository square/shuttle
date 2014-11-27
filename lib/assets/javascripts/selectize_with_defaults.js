/**
 * Copyright 2014 Square Inc.
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

/**
 * A jquery plugin on top of the 'selectize' plugin, which adds the default values
 * in the target field as selected options.
 * This is necessary because selectize.js doesn't respect defaults and removes them.
 * If and when selectize implements this functionality, this method can be removed.
 */

(function( $ ) {
    $.fn.selectizeWithDefaults = function(options) {
        return this.each ( function() {
            var $this = $(this);
            var original_values = $this.val().split(options['delimiter'])
            var selectize = $this.selectize(options)[0].selectize
            var i;
            for (i = 0; i < original_values.length; i++) {
                value = original_values[i].trim()
                var option = {}
                option[options['labelField']] = value
                option[options['valueField']] = value
                selectize.addOption(option)
                selectize.addItem(value)
            }
            selectize.refreshOptions()
            selectize.refreshItems()
        });
    };
}( jQuery ));
