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

root = exports ? this

root.loadFuzzyMatches = ($fuzzy_matches, $copy_field, fuzzy_match_url, source_copy) ->
    $fuzzy_matches.empty()
    $fuzzy_matches.append($('<dd/>').text('Loading fuzzy matches'))

    $.ajax fuzzy_match_url,
        data:
            source_copy: source_copy
        success: (matches) =>
            $fuzzy_matches.empty()
            if matches.length == 0
                $fuzzy_matches.append($('<dd/>').text('No fuzzy matches found :('))
            else
                for match in matches
                    do (match) =>
                        match_percentage = $('<span/>').addClass("match-percentage").text("(#{match.match_percentage.toString()[0..4]}%) ")
                        match_element = $('<a/>').append($('<span/>').text("(#{match.rfc5646_locale}) "))
                                                 .append(match_percentage)
                                                 .append($('<span/>').addClass('fuzzy-matched-copy').text(match.copy))
                                                 .append($('<span/>').addClass('changed').text(source_copy).hide())
                                                 .append($('<span/>').addClass('original').text(match.source_copy).hide())

                        match_wrapper = $('<dd/>').append(match_element)
                                                  .append($('<div/>').addClass('diff'))

                        match_element.click =>
                            $copy_field.val match.copy

                        match_element.mouseenter ->
                            match_element.prettyTextDiff
                                diffContainer: match_wrapper.find('.diff')
                            match_wrapper.find('.diff').prepend($('<span/>').addClass("match-percentage").text("Source Diff: "))
                        match_element.mouseleave ->
                            match_wrapper.find('.diff').empty()

                        $fuzzy_matches.append(match_wrapper)

