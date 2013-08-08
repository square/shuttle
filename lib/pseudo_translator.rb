# Copyright 2013 Square Inc.
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
#   PseudoTranslator.pseudo_translation_for("a word")
#     => "éßt inventore"
#     => "ut fügå"
#   PseudoTranslator.pseudo_translation_for("a slightly longer and more complex phrase")
#     => "molestiae eius éå vél cum åüþ aut"
#     => "nòn quia qüîå quis quis rém qui"

class PseudoTranslator

  # @param [Locale] the Locale you want this PseudoTranslator to produce
  #   translations in. Must be a pseudo-locale (i.e. have the "pseudo"
  #   variant).
  def initialize(locale)
    raise ArgumentError("Not a pseudo-locale") unless locale.pseudo?
    raise ArgumentError("Not a supported locale") unless self.class.supported_rfc5646_locales.include? locale.name
    @locale = locale
  end

  def self.supported_rfc5646_locales
    ["en-pseudo"]
  end

  # @param [String] source_copy The original string
  # @return [String] A tricky string of approximately the same form
  def pseudo_translation_for(source_copy)
    sentences = source_copy.split(".")
    words = source_copy.split
    if words.count == 1
      pseudo_word
    elsif sentences.count == 1
      pseudo_phrase(words.count)
    else
      pseudo_paragraph(sentences.count)
    end
  end

  private

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

  def spicefy(phrase)
    spices.reduce(phrase) do |p, spice|
      k = spice[0]
      v = spice[1]
      p.sub(/#{k}/, v)
    end
  end

  def short_words
    @short_words ||= Faker::Base.translate('faker.lorem.words', locale: @locale).select{ |w| w.length <= 5 }
  end
  def long_words
    @long_words ||= Faker::Base.translate('faker.lorem.words', locale: @locale).select{ |w| w.length > 6 }
  end

  def pseudo_short_word
    short_words.sample
  end

  def pseudo_long_word
    long_words.sample
  end

  def pseudo_word(short_rate=0.5, spice_rate=0.5)
    word = rand < short_rate ? pseudo_short_word : pseudo_long_word
    rand < spice_rate ? spicefy(word) : word
  end
  def pseudo_phrase(num_words=rand(3..15))
    (1..num_words).map { |_| pseudo_word(0.8) }.join(" ")
  end

  def pseudo_paragraph(num_sentences)
    (1..num_sentences).map { |_| pseudo_phrase }.join(". ")
  end
end
