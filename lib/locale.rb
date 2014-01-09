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

# Represents a locale that can be localized to. Locales are identified by
# their RFC 5646 code, which can be as simple as just a language (e.g., "en" for
# English), or arbitrary complex (e.g., "zh-cmn-Hans-CN" for Mandarin Chinese
# as spoken in China, simplified Han orthography). The entire RFC 5646 spec is
# supported by this class.

class Locale
  # @private
  RFC5646_EXTLANG   = /(?<extlang>[a-zA-Z]{3})(-[a-zA-Z]{3}){0,2}/
  # @private
  RFC5646_ISO639    = /(?<iso639>[a-zA-Z]{2,3})(-#{RFC5646_EXTLANG.source})?/
  # @private
  RFC5646_RESERVED  = /(?<reserved>[a-zA-Z]{4})/
  # @private
  RFC5646_SUBTAG    = /(?<subtag>[a-zA-Z]{5,8})/
  # @private
  RFC5646_REGION    = /(?<region>([a-zA-Z]{2}|\d{3}))/
  # @private
  RFC5646_VARIANT   = /([a-zA-Z0-9]{5,8}|\d[a-zA-Z0-9]{3})/
  # @private
  RFC5646_SCRIPT    = /(?<script>[a-zA-Z]{4})/
  # @private
  RFC5646_EXTENSION = /([0-9A-WY-Za-wy-z](-[a-zA-Z0-9]{2,8}){1,})/
  # @private
  RFC5646_LANGUAGE  = /(#{RFC5646_ISO639.source}|#{RFC5646_RESERVED.source}|#{RFC5646_SUBTAG.source})/
  # @private
  RFC5646_PRIVATE   = /x(?<privates>(-[a-zA-Z0-9]{1,8}){1,})/
  # @private
  RFC5646_FORMAT    = /\A#{RFC5646_LANGUAGE.source}(-#{RFC5646_SCRIPT.source})?(-#{RFC5646_REGION.source})?(?<variants>(-#{RFC5646_VARIANT.source})*)(?<extensions>(-#{RFC5646_EXTENSION.source})*)(-#{RFC5646_PRIVATE.source})?\z/

  # @return [String] The ISO 639 code for the base language (e.g., "de" for
  #   German).
  attr_reader :iso639
  # @return [String] The RFC 5646 code for the orthography (e.g., "Arab" for
  #   Arabic script).
  attr_reader :script
  # @return [String] The ISO 3166 country code for the regional dialect (e.g.,
  #   "BZ" for Belize). Some special values are also supported (e.g., "013" for
  #   Central America); see the spec for details.
  attr_reader :region
  # @return [Array<String>] The variant or nested subvariant of this locale.
  #   The full path to a subvariant is listed as a top-level Array; an example
  #   is `["sl", "rozaj", "1994"]`, indicating the 1994 standardization of the
  #   Resian orthography of the Rozaj dialect of Slovenian (in case we should
  #   ever want to localize one of our projects thusly). Variants can be
  #   regional or temporal dialects, or orthographies, or both, and are very
  #   specific.
  attr_reader :variants
  # @return [String] The dialect (not associated with a specific region or
  #   period in time) specifier. For example, "yue" indicates Yue Chinese
  #   (Cantonese).
  attr_reader :extended_language
  # @return [Array<String>] The user-defined extensions applied to this
  #   locale. The meaning of these is not specified in the spec, and left up
  #   to private use, and is ignored by this class, but stored for completeness.
  attr_reader :extensions

  # Generates a new instance from an RFC 5646 code.
  #
  # @param [String] ident The RFC 5646 code for the locale.
  # @return [Locale] The instance representing that locale.

  def self.from_rfc5646(ident)
    ident = ident.gsub('_', '-')
    return nil unless (matches = RFC5646_FORMAT.match(ident))
    attrs = RFC5646_FORMAT.named_captures.inject({}) do |hsh, (name, offsets)|
      hsh[name] = offsets.map { |offset| matches[offset] }.compact
      hsh
    end

    iso639 = attrs['iso639'].first
    script = attrs['script'].first
    return nil unless iso639
    region = attrs['region'].first
    if (variants = attrs['variants'].first)
      variants = variants.split('-')
      variants.shift
    end
    if (extensions = attrs['extensions'].first)
      extensions = extensions.split('-')
      extensions.shift
    end
    extlang = attrs['extlang'].first

    Locale.new iso639, script, extlang, region, variants || [], extensions || []
  end

  # Returns an array of Locales representing all possible completions given a
  # prefix portion of an RFC 5646 code. The resolution of the resultant array is
  # determined by the resolution if the input prefix. Some examples:
  #
  # * If just the letter "e" is entered, Locales whose ISO 639 codes begin
  #   with the letter "e" will be returned (English, Spanish, etc.). These
  #   Locale instances will have no other fields specified.
  # * If "en-U" is specified, Locale instances representing "en-US" and
  #   "en-UA", among others, will be returned, as well as "en-Ugar" (for all the
  #   sense it makes). "en-US-Ugar" would not be returned, as it is of a higher
  #   resolution than the input.
  #
  # @param [String] prefix A portion of an RFC 5646 code.
  # @param [Fixnum] max A maximum number of completions to return.
  # @return [Array<Locale>] Candidate completions as Locale instances.

  def self.from_rfc5646_prefix(prefix, max=nil)
    if prefix.include?('-')
      prefix_path   = prefix.split('-')
      prefix        = prefix_path.pop
      parent_prefix = prefix_path.join('-')
      parent        = from_rfc5646(parent_prefix)
      return [] unless parent

      search_paths = if parent.variants.present?
                       #TODO subvariants
                       []
                     elsif parent.region # only possible completions are variants
                       []
                       #TODO variants
                     elsif parent.script # can be followed with variant or region
                       %W(locale.region)
                     else # can be followed with script, region, or variant
                       %W(locale.region locale.script)
                     end

      keys = search_paths.map { |path| I18n.t(path).select { |k, v| Locale.matches_prefix? prefix, k, v }.keys }.flatten
      keys.delete '_END_'
      keys = keys[0, max] if max

      return keys.map { |key| from_rfc5646 "#{parent_prefix}-#{key}" }
    else
      keys = I18n.t('locale.name').select { |k, v| Locale.matches_prefix? prefix, k, v }.keys
      keys = keys[0, max] if max
      return keys.map { |key| from_rfc5646 key }
    end
  end

  # @private
  def initialize(iso639, script=nil, extlang=nil, region=nil, variants=[], extensions=[])
    @iso639            = iso639.try!(:downcase)
    @region            = region.try!(:upcase)
    @variants          = variants.map(&:downcase)
    @extended_language = extlang.try!(:downcase)
    @extensions        = extensions
    @script            = script
  end

  # @return [String] The full RFC 5646 code for this locale.

  def rfc5646
    [iso639, script, extended_language, region, *variants].compact.join('-')
  end
  alias to_param rfc5646

  # Returns a human-readable localized name of the locale.
  #
  # @param [String] locale The locale to use (default locale is used by
  #   default).
  # @return [String] The localized name of the locale.

  def name(locale=nil)
    I18n.with_locale(locale || I18n.locale) do
      i18n_language = if extended_language
                        I18n.t "locale.extended.#{iso639}.#{extended_language}"
                      else
                        I18n.t "locale.name.#{iso639}"
                      end

      i18n_dialect = if variants.present?
                       I18n.t "locale.variant.#{iso639}.#{variants.join '.'}._END_"
                     else
                       nil
                     end

      i18n_script = script ? I18n.t("locale.script.#{script}") : nil
      i18n_region = region ? I18n.t("locale.region.#{region}") : nil

      if i18n_region && i18n_dialect && i18n_script
        I18n.t 'locale.format.scripted_regional_dialectical', script: i18n_script, dialect: i18n_dialect, region: i18n_region, language: i18n_language
      elsif i18n_region && i18n_dialect
        I18n.t 'locale.format.regional_dialectical', dialect: i18n_dialect, region: i18n_region, language: i18n_language
      elsif i18n_region && i18n_script
        I18n.t 'locale.format.scripted_regional', script: i18n_script, region: i18n_region, language: i18n_language
      elsif i18n_dialect && i18n_script
        I18n.t 'locale.format.scripted_dialectical', script: i18n_script, dialect: i18n_dialect, language: i18n_language
      elsif i18n_script
        I18n.t 'locale.format.scripted', script: i18n_script, language: i18n_language
      elsif i18n_dialect
        I18n.t 'locale.format.dialectical', dialect: i18n_dialect, language: i18n_language
      elsif i18n_region
        I18n.t 'locale.format.regional', region: i18n_region, language: i18n_language
      else
        i18n_language
      end
    end
  end

  # Tests for equality between two locales. Their full RFC 5646 codes must be
  # equal.
  #
  # @param [Locale] other Another Locale.
  # @return [true, false] Whether it is the same Locale as the receiver.
  # @raise [ArgumentError] If `other` is not a Locale.

  def ==(other)
    case other
      when Locale
        rfc5646 == other.rfc5646
      else
        false
    end
  end
  alias eql? ==
  alias equal? ==
  alias === ==

  # @private
  def hash() rfc5646.hash end

  # Returns the fallback order for this Locale. For example, fr-CA might
  # fall back to fr, which then falls back to en. The fallback order is
  # described in the `fallbacks.yml` file.
  #
  # @return [Array<Locale>] The fallback order of this locale, from most
  #   specific to most general. Note that this array includes the receiver.

  def fallbacks
    fallbacks = Array.wrap(self.class.fallbacks[rfc5646]).
        map { |l| self.class.from_rfc5646 l }
    fallbacks.unshift self
    return fallbacks
  end

  # Returns whether this Languge is a subset of the given locale. "en-US" is a
  # child of "en".
  #
  # @param [Locale] parent Another locale.
  # @return [true, false] Whether this locale is a child of `parent`.

  def child_of?(parent)
    return false if iso639 != parent.iso639
    return false if parent.specificity > specificity
    parent.specified_parts.all? { |part| specified_parts.include?(part) }
  end

  # @return [true, false] Whether this locale is a pseudo-locale.
  def pseudo?
    return variants.include? "pseudo"
  end

  # @private
  def specificity
    specificity = 1
    specificity += 1 if script
    specificity += 1 if region
    specificity += variants.size
    specificity += 1 if extended_language
    specificity += extensions.size
  end

  # @private
  def specified_parts
    # relies on the fact that the namespace for each element of the code is
    # *globally* unique, not just unique to the code element
    (variants + extensions + [script, region, extended_language]).compact
  end

  # @private
  def as_json(options=nil)
    {
        rfc5646:    rfc5646,
        components: {
            iso639:            iso639,
            script:            script,
            extended_language: extended_language,
            region:            region,
            variants:          variants,
            exensions:         extensions
        },
        name:       name,
    }
  end

  # @private
  def inspect() "#<#{self.class.to_s} #{rfc5646}>" end

  # @private
  def self.matches_prefix?(prefix, key, value)
    return false unless value.kind_of?(String)
    return true if key.to_s.downcase.starts_with?(prefix.downcase)
    return true if value.split(/\w+/).any? { |word| word.downcase.starts_with? prefix.downcase }
    return false
  end

  private

  def self.fallbacks
    @fallbacks ||= YAML.load_file(Rails.root.join('data', 'fallbacks.yml'))
  end
end
