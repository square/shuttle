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

# A library that generates Western mostly Latin-alphabet text to challenge
# rendering of translated texts.
#
# @example
#   p = PseudoTranslator.new(Locale.from_rfc5646("en-pseudo"))
#   p.translate("a word")
#     => "éßt inventore"
#     => "ut fügå"
#   p.translate("a slightly longer and more complex phrase")
#     => "molestiae eius éå vél cum åüþ aut"
#     => "nòn quia qüîå quis quis rém qui"

class PseudoTranslator

  # @param [Locale] locale The Locale you want this PseudoTranslator to produce
  #   translations in. Must be a pseudo-locale (i.e. have the "pseudo"
  #   variant).
  def initialize(locale)
    raise ArgumentError, "Not a pseudo-locale" unless locale.pseudo?
    raise ArgumentError, "Not a supported locale" unless self.class.supported_rfc5646_locales.include? locale.rfc5646
    @locale = locale
  end

  # @return [Array<String>] The supported pseudo-locale codes.
  def self.supported_rfc5646_locales
    %w(en-pseudo)
  end

  # @return [Array<Locale>] The supported pseudo-locales.
  def self.supported_locales
    supported_rfc5646_locales.map { |l| Locale.from_rfc5646(l) }
  end

  # Pseudo-translates a source string.
  #
  # @param [String] source_copy The original string.
  # @return [String] A tricky string of approximately the same form.

  def translate(source_copy)
    sentences = source_copy.split(".")
    words = sentences.map { |s| s.split(" ") }
    currency_indexes = words.flatten.each_with_index.select { |w, i| w.match(/[#{currencies}]/) }.map { |_, i| i }
    to_return = if words.flatten.count == 1
      pseudo_word
    elsif sentences.count == 1
      pseudo_phrase(words.flatten.count)
    else
      pseudo_paragraph(words.map { |s| s.count })
    end
    add_currencies(to_return, currency_indexes)
  end

  private

  # Generating words

  def pseudo_word(short_rate=0.5, spice_rate=0.5)
    word = rand < short_rate ? pseudo_short_word : pseudo_long_word
    rand < spice_rate ? spicefy(word) : word
  end
  def pseudo_phrase(num_words=rand(3..15))
    (1..num_words).map { |_| pseudo_word(0.8) }.join(" ")
  end
  def pseudo_paragraph(words_per_sentence)
    words_per_sentence.map { |num_words| pseudo_phrase(num_words) }.join(". ")
  end

  # Specifics

  def short_words
    @short_words ||= Faker::Base.translate('faker.lorem.words', locale: @locale.rfc5646).select{ |w| w.length <= 5 }
  end
  def long_words
    @long_words ||= Faker::Base.translate('faker.lorem.words', locale: @locale.rfc5646).select{ |w| w.length > 6 }
  end

  def pseudo_short_word
    short_words.sample[0..rand(1..5)]
  end

  def pseudo_long_word
    long_words.sample(rand(1..3)).join("")
  end

  # For adding enhancements to strings

  def add_currencies(phrase, currency_indexes)
    return phrase if currency_indexes.empty?
    words = phrase.split(" ")
    currency_indexes.each { |i| words[i] = currencies + words[i] }
    words.join(" ")
  end

  def currencies
    [
      "$",
      "\u00A2", # ¢, US cents
      "\u00A3", # £, British pound
      "\u00A5", # Yen
      "\u20AC", # €, Euro
    ].join("")
  end

  def spicefy(phrase)
    punctuate_rate = 0.4
    code_rate = 0.1
    word = spices.reduce(phrase) { |p, spice|
      k = spice[0]
      v = spice[1]
      p.sub(/#{k}/, v)
    } + (rand < punctuate_rate ? punctuation : "")
    rand < code_rate ? codify(word) : word
  end

  def spices
    [
      # Spanish
      ["e", "\u00E9"], # é, acute accent

      # French
      ["o", "\u00F2"], # ò, Grave accent
      ["u", "\u00FC"], # ü, umlaut
      ["i", "\u00EE"], # î, circumflex
      ["c", "\u00E7"], # ç, limaçon

      # Swedish
      ["a", "\u00E5"], # å, a-ring
      ["A", "\u00C5"], # Å,

      # Czech
      ["c", "\u010D"], # č, háček

      # German
      ["s", "\u00DF"], # ß, esset

      # Hungarian
      ["o", "\u0151"], # ő, double accent

      # Icelandic
      ["t", "\u00FE"], # þ, thorn
    ]
  end

  def code_strings
    [
      "\#\{%s\}",
      "\%\@%s",
      "\%o%s",
      "\%d%s",
      "\%x%s",
      "%%",
    ]
  end
  def codify(word)
    code_strings.sample.sub("%s", word)
  end

  def simple_punctuation
    '!@#$%^&*()[]{}/=\?+|;:,<>\'"`~-_'.chars.to_a
  end
  def international_punctuation
    [
      "\u00A1", # ¿
      "\u00BF", # ¡
      "\u2018", # Curly left quote
      "\u2019", # Curly apostrophe
      "\u2026", # …
      "\u2030", # ‰
      "\u2031", # ‱
      "\u2032", # 'prime' apostrophe
      "\u203D", # Interrobang
      "\u22EE", # Vertical ellipsis
      "\u22EF", # Midline ellipsis
      "\uFE10", # Fancy comma
    ]
  end
  def punctuation(international_rate=0.8)
    rand < international_rate ? international_punctuation.sample : simple_punctuation.sample
  end
end
