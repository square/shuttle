require 'nokogiri'

class TmxBuilder
  def initialize(project)
    @project = project
  end

  def tmx
    stale_cache? ? build_tmx : cached_tmx
  end

  def cached_tmx
    Rails.cache.read(cache_key)
  end

  def build_tmx
    tmx = Nokogiri::XML::Builder.new do |xml|
      xml.tmx(version: 1.4) {
        xml.header(datatype: 'PlainText') {
          xml.generatedAt Time.zone.now.to_i
        }
        xml.body {
          translation_units.each_with_index do |tu, i|
            tuvs = segments_by_lang(tu)
            seg_count = tuvs[@project.base_rfc5646_locale].try(:count).to_i

            tuvs.select! { |_, segs| segs.try(:count) == seg_count }
            if tuvs.count > 1
              xml.tu(tuid: tuid(tu)) {
                tuvs.each do |lang_code, segs|
                  xml.tuv("xml:lang" => sanitize_lang_code(lang_code)) {
                    Array(segs).each do |seg|
                      xml.seg(seg)
                    end
                  }
                end
              }
            end
          end
        }
      }
    end.doc.root.to_s

    Rails.cache.write(cache_key, tmx)
    tmx
  end

  def generated_at
    Time.zone.at(cached_tmx.to_s.match(/<generatedAt>(\d+)<\/generatedAt>/).try(:[], 1).to_i)
  end

  private

  def translation_units
    if @project.git?
      @project.commits.last.try(:keys) || []
    else
      @project.articles.select { |a| !a.hidden }.map(&:sections).flatten
    end
  end

  def tuid(translation_unit)
    if translation_unit.is_a?(Key)
      "#{translation_unit.project.name.parameterize}.#{translation_unit.original_key}"
    elsif translation_unit.is_a?(Section)
      "#{translation_unit.project.name.parameterize}.#{translation_unit.article.name.parameterize}"
    end
  end

  def segments_by_lang(translation_unit)
    if translation_unit.is_a?(Key)
      translation_unit.translations.map do |t|
        [t.rfc5646_locale, sentence_split(t.copy)]
      end.to_h
    elsif translation_unit.is_a?(Section)
      translations = translation_unit.keys.map do |key|
        key.translations.map { |t| [t.rfc5646_locale, t.copy] }.to_h
      end
      translations.first.keys.map do |lang_code|
        [lang_code, translations.map { |t| sentence_split(t[lang_code]) }.flatten]
      end.to_h
    end
  end

  def sentence_split(str)
    str.to_s.split(/(?<=[\.\!\?]) /)
  end

  def stale_cache?
    cached_tmx.blank? || @project.translations.last.updated_at > generated_at
  end

  def cache_key
    "tmx:#{@project.name}"
  end

  def sanitize_lang_code(lang_code)
    {
      'en' => 'en-US',
      'es' => 'es-US',
      'ja' => 'ja-JP',
      'fr' => 'fr-CA',
    }[lang_code.to_s] || lang_code
  end
end
