#!/usr/local/bin/env ruby

require "csv"
require "byebug"

#  ABOUT
#---------
# this script can be used to replace words in en-US with variant words
# in other locales, e.g. a word like color -> colour

# clear the output buffer first
system "clear" or system "cls"

CSV_FILE_PATH = 'replacement_results.csv'
# get variant words from Google Drive: https://docs.google.com/spreadsheets/d/1NVaPqEz-R5UiAYHfNPYOlOyIVCwA7dAz5xtuvjXbVAg/edit?usp=sharing
variant_words=
[
    # [source, en-GB source, en-GB replacement, en-CA source, en-CA replacement, en-AU source, en-AU replacement]
    ["Authorization", "Authorization", "Authorisation", "Authorisation", "Authorization", "Authorization", "Authorisation"],
    ["Authorize", "Authorize", "Authorise", "Authorise", "Authorize", "Authorize", "Authorise"],
    ["Authorized", "authorised", "authorised", "authorized", "authorized", "authorised", "authorised"],
    ["authorizing", "authorising", "authorising", "authorizing", "authorizing", "authorising", "authorising"],
    ["Canceled", "Cancelled", "Cancelled", "Cancelled", "Cancelled", "Cancelled", "Cancelled"],
    ["canceling", "cancelling", "cancelling", "cancelling", "cancelling", "cancelling", "cancelling"],
    ["cancellation", "cancellation", "cancellation", "cancellation", "cancellation", "cancellation", "cancellation"],
    ["Customize", "Customise", "Customise", "Customize", "Customize", "Customise", "Customise"],
    ["customized", "customised", "customised", "customized", "customized", "customised", "customised"],
    ["Enroll", "Enrol", "Enrol", "Enrol", "Enrol", "Enrol", "Enrol"],
    ["enrolled", "enrolled", "enrolled", "enrolled", "enrolled", "enrolled", "enrolled"],
    ["enrollment", "enrolment", "enrolment", "enrolment", "enrolment", "enrolment", "enrolment"],
    ["enrolling", "enrolling", "enrolling", "enrolling", "enrolling", "enrolling", "enrolling"],
    ["initialize", "initialise", "initialise", "initialize", "initialize", "initialise", "initialise"],
    ["initialized", "--", "initialised", "--", "initialized", "--", "initialised"],
    ["initializing", "--", "initialising", "--", "initializing", "--", "initialising"],
    ["initialization", "--", "initialisation", "--", "initialization", "--", "initialisation"],
    ["Personalize", "Personalise", "Personalise", "Personalize", "Personalize", "Personalise", "Personalise"],
    ["Personalization", "Personalisation", "Personalisation", "Personalization", "Personalization", "Personalisation", "Personalisation"],
    ["Uncategorized", "Uncategorised", "Uncategorised", "Uncategorized", "Uncategorized", "Uncategorised", "Uncategorised"],
    ["Wifi", "Wi-fi", "Wi-fi", "Wi-fi", "Wi-fi", "Wi-fi", "Wi-fi"],
    ["fulfillment", "fulfillment", "fulfilment", "fulfillment", "fulfillment", "fulfillment", "fulfilment"],
]

# helper method to print things while debugging
def pp(input, linesAfter=true, linesBefore=true)
    if linesBefore == true
        puts "-" * [(input.size + 2), 15].min
    end
    puts input
    if linesAfter == true
        puts "-" * [(input.size + 2), 15].min
    end
end

# finds replaceable word pairs in a given locale
# locale: string
# variant_words: hash object containing all variants for given locale
# returns Hash (of arrays for each locale)
def find_replacement_translations(locale, variant_words, translations)
    pp "Processing #{locale} strings"
    unchanged = []
    to_be_replaced = []
    variant_words.each do |dict|
        current = dict[:source]
        origin = dict[:origin]
        replacement = dict[:target]
        # keeping a tally of how many will not change due to both current
        # and replacement being the same
        if current == replacement
            unchanged << { current: current, replacement: replacement }
            next
        end
        if current == '--'
            t = translations.where('copy LIKE ?', "%#{origin}%")
            puts "#{t.count} strings found in #{locale} for #{origin}"
        else
            t = translations.where('copy LIKE ?', "%#{current}%")
            puts "#{t.count} strings found in #{locale} for #{current}"
        end
        # t = translations.where(source_copy: source)
        # count = t.count
        # t = t.concat(fuzzy_match)
        unless (t.nil? or t.empty?) && current[0] != replacement[0]
            # pp "#{current[0]} matched #{replacement[0]}"
            t.each do |row|
                # exact match with word boundaries around the word
                # this will prevent words being part of ids/classes
                # and it will also prevent words like "Unenroll"
                # it's looking for "enroll"
                unless row.copy.match(/#{current}\b/)
                    next
                end
                if current[0] == replacement[0]
                    pp "#{current} will be replaced with #{replacement}"
                end
                rep = {
                    locale: locale,
                    source: row.source_copy,
                    current: row.copy,
                    replacement: row.copy && row.copy.gsub(current, replacement),
                    id: row.id,
                    word: replacement,
                }
                if rep[:current] != rep[:replacement]
                    puts "Current and replacmeent match: #{rep[:current]} == #{rep[:replacement]}"
                    begin
                        if rep[:replacement].strip_html_tags == rep[:replacement]
                            to_be_replaced << rep
                        else
                            pp "Stripped #{rep[:replacement]} and didn't add to list"
                        end
                    end
                end
            end
        end
    end
    puts "Ignoring: #{unchanged.size} strings"
    puts "Changing: #{to_be_replaced.size} strings"
    to_be_replaced
end

# this method builds a locale specific hash of all words
# returns Hash (locale based arrays of words)
def build_variant_replacements(variant_words)
    # first check if the number of words in a given set is not 7
    # (meaning doesn't include all source/target for each locale + source)
    invalid_variant_words = variant_words.select { |words| words.count != 7 }
    unless invalid_variant_words.empty?
        pp "Found Invalid Variants: #{invalid_variant_words}"
        raise Exception.new("Found Invalid Variants: #{invalid_variant_words.count}")
    end
    locale_words = { 'en-GB' => [], 'en-CA' => [], 'en-AU' => [], }
    variant_words.each do |source, gb_source, gb_target, ca_source, ca_target, au_source, au_target|
        puts "A single row below:"
        puts "#{source}, #{gb_source}, #{gb_target}, #{ca_source}, #{ca_target}, #{au_source}, #{au_target}"
        locale_words['en-GB'] << { origin: source, source: gb_source, target: gb_target }
        # puts locale_words['en-GB']
        locale_words['en-CA'] << { origin: source, source: ca_source, target: ca_target }
        pp locale_words
        # puts locale_words['en-CA']
        locale_words['en-AU'] << { origin: source, source: au_source, target: au_target }
        # puts locale_words['en-AU']
    end
    locale_words
end

# this method will case a given array into uppercase, lowercase, and sentence case
# returns Array (all case converted words and original words)
def add_casing_types(original_array)
    lowercase_array = []
    uppercase_array = []
    capitalized_array = []
    # go over original_array once to to create temporary arrays
    original_array.each do |array|
        temp_lowercase_array = []
        temp_uppercase_array = []
        temp_capitalized_array = []
        array.each do |word|
            temp_lowercase_array << word.downcase
            temp_uppercase_array << word.upcase
            # split the first letter, capitalize it
            temp_capitalized_array << word.split.map(&:capitalize)[0]
        end
        lowercase_array << temp_lowercase_array
        uppercase_array << temp_uppercase_array
        capitalized_array << temp_capitalized_array
    end
    # appending because at this point, we'll want to append a cased array
    # just like any other list of words
    final_array = [].concat(lowercase_array)
    final_array = final_array.concat(uppercase_array)
    final_array = final_array.concat(capitalized_array)
end

# 1st:
# we add all the different cases to each row
# an example this will look like this:
# original row:     ['Enroll', 'Enrol', 'Enrol'...etc]
# uppercase row:    ['ENROLL', 'ENROL', 'ENROL'...etc]
# lowercase row:    ['enroll', 'enrol', 'enrol'...etc]
# capitalized case: ['Enroll', 'Enrol', 'Enrol'...etc]
cased_variant_words = add_casing_types(variant_words)

# 2nd:
# we build individual hashes of each locale
# e.g.
# { 'en-GB: {origin: 'Enroll', source: 'Enrol', replacement: 'Enrol'} }
# note: origin is the en-US source origin
variant_words_dict = build_variant_replacements(cased_variant_words)

# 3rd:
# Write headers to CSV file
CSV.open(CSV_FILE_PATH, 'w') do |csv|
    csv << ['locale', 'word', 'current', 'replacement', 'translation_id']
end

# 4th:
# find replacements for each locale and add to CSV file
variant_words_dict.each do |locale, words_for_locale|
    translations = Translation.where(rfc5646_locale: locale)
    locale_replacements = find_replacement_translations(locale, words_for_locale, translations)
    locale_replacements.each do |rep|
        CSV.open(CSV_FILE_PATH, 'a+') do |csv|
            csv << [rep[:locale], rep[:word], rep[:current], rep[:replacement], rep[:id]]
        end
    end
end

