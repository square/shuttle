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


class PseudoTranslator
  class << self
    def pseudo_rfc5646
      "en-pseudo"
    end

    def pseudo_locale
      Locale.from_rfc5646(pseudo_rfc5646)
    end

    def pseudo_translation_for(source_copy)
      sentences = source_copy.split(".")
      words = source_copy.split
      if words.count == 1
        pseudo_word
      elsif sentences.count == 1
        pseudo_phrase(words.count)
      elsif
        pseudo_paragraph(sentences.count)
      end
    end

    private

    def spicefy(phrase)
      # Spanish
      phrase.sub!(/e/, "\u00E9") # é, acute accent

      # French
      phrase.sub!(/o/, "\u00F2") # ò, Grave accent
      phrase.sub!(/u/, "\u00FC") # ü, umlaut
      phrase.sub!(/i/, "\u00EE") # î, circumflex
      phrase.sub!(/c/, "\u00E7") # ç, limaçon

      # Swedish
      phrase.sub!(/a/, "\u00E5") # å, a-ring
      phrase.sub!(/A/, "\u00C5") # Å,

      # Czech
      phrase.sub!(/c/, "\u010D") # č, háček

      # German
      phrase.sub!(/s/, "\u00DF") # ß, esset

      # Hungarian
      phrase.sub!(/o/, "\u030B") # ő, double accent

      # Icelandic
      phrase.sub!(/t/, "\u00FE") # þ, thorn

      phrase
    end

    def short_words
      @short_words ||= Faker::Base.translate('faker.lorem.words').select{ |w| w.length < 5 }
    end
    def long_words
      @long_words ||= Faker::Base.translate('faker.lorem.words').select{ |w| w.length > 8 }
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

    def pseudo_weird
    end
  end
end
