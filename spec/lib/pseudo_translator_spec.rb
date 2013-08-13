require 'spec_helper'

describe PseudoTranslator do
  context "::supported_rfc5646_locales" do
    it "should all have pseudo" do
      expect(PseudoTranslator.supported_rfc5646_locales.all? { |l| l.match /pseudo/ }).to eq(true)
    end
  end

  let(:p) { PseudoTranslator.new(PseudoTranslator.supported_locales.first) }

  context "#pseudo_word" do
    subject { p.send(:pseudo_word) }
    it "should only return one word" do
      expect(subject.split(" ").count).to eq(1)
    end
  end

  context "#pseudo_phrase" do
    let(:num_words) { 10 }
    subject { p.send(:pseudo_phrase, num_words) }
    it "should return the specified number of words" do
      expect(subject.split(" ").count).to eq(num_words)
    end
  end

  context "#pseudo_paragraph" do
    let(:sentence_word_counts) { [5, 3, 8, 15] }
    subject { p.send(:pseudo_paragraph, sentence_word_counts) }
    it "should return the specified number of words and sentences" do
      expect(subject.split(".").count).to eq(sentence_word_counts.count)
      expect(subject.split(" ").count).to eq(sentence_word_counts.reduce(:+))
    end
  end

  context "#translate" do
    let(:words_per_sentence) { 5 }
    let(:sentences) { 10 }
    let(:paragraph) { ((" aoeu" * words_per_sentence) + ".") * sentences }
    subject { p.translate(paragraph) }
    it "should return the right number of words and sentences" do
      expect(subject.split(".").count).to eq(sentences)
      expect(subject.split(" ").count).to eq(sentences * words_per_sentence)
    end
  end
end
