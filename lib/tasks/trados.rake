# Copyright 2015 Square Inc.
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

require 'digest/sha1'

class TradosImporter
  SAMPLE_CMD = "rake trados:import[/path/to/file.xml,1,'Space Station',en,EN-US,es,ES-XM]"

  def initialize(filepath, project_id, project_name, source_rfc5646_locale, source_rfc5646_rep, target_rfc5646_locale, target_rfc5646_rep)
    @filepath = filepath
    @source_rfc5646_locale = source_rfc5646_locale
    @source_rfc5646_rep = source_rfc5646_rep
    @target_rfc5646_locale = target_rfc5646_locale
    @target_rfc5646_rep = target_rfc5646_rep
    @project = Project.not_git.find(project_id)

    # This is to reduce the chances of an input error because it's easy to make and cleaning up is hard.
    fail('Are you sure this is the right project id?') unless @project.name == project_name
  end

  def import
    verify_inputs

    units = parse_translation_units
    units = remove_duplicate_translation_units(units)
    units = remove_empty_translation_units(units)

    articles = units.map(&:article)
    validate_articles!(articles)
    save_articles(articles)
    wait_until_all_articles_are_loaded(articles)
    add_translations(units)

    puts "Running ProjectDescendantsRecalculator"
    ProjectDescendantsRecalculator.new.perform(@project.id)
  end

  def verify_inputs
    fail "Missing filepath. ex: #{SAMPLE_CMD}" if @filepath.blank?
    fail "Missing source_rfc5646_locale. ex: #{SAMPLE_CMD}" if @source_rfc5646_locale.blank?
    fail "Missing source_rfc5646_rep. ex: #{SAMPLE_CMD}" if @source_rfc5646_rep.blank?
    fail "Missing target_rfc5646_locale. ex: #{SAMPLE_CMD}" if @target_rfc5646_locale.blank?
    fail "Missing target_rfc5646_rep. ex: #{SAMPLE_CMD}" if @target_rfc5646_rep.blank?
  end

  def parse_translation_units
    doc = Nokogiri::XML(File.open(@filepath))

    doc.xpath('//body/tu').map do |tu|
      source_arr = tu.css('tuv').select { |tuv| tuv.attr('xml:lang') == @source_rfc5646_rep }
      target_arr = tu.css('tuv').select { |tuv| tuv.attr('xml:lang') == @target_rfc5646_rep }

      if source_arr.length != 1
        fail("Expected 1 tuv with source_rfc5646_rep = #{@source_rfc5646_rep}. Found #{source_arr.length}. tu = #{tu}")
      end

      if target_arr.length != 1
        fail("Expected 1 tuv with target_rfc5646_rep = #{@target_rfc5646_rep}. Found #{target_arr.length}. tu = #{tu}")
      end

      timestamp_str = tu.attr('creationdate')
      source_copy = source_arr.first.css('seg').text
      target_copy = target_arr.first.css('seg').text

      unit = TranslationUnit.new(source_copy, target_copy, timestamp_str)
      set_article(unit)
      unit
    end
  end

  def set_article(unit)
    article = @project.articles.find_by_name(unit.article_name)
    if article
      unless unit.sections_hash == article.sections_hash
        fail("Not allowed to update existing article's sections_hash. " +
                 "Old: #{article.sections_hash}, New: #{unit.sections_hash}")
      end

      unless @source_rfc5646_locale == article.base_rfc5646_locale
        fail("Not allowed to update existing article's base_rfc5646_locale. " +
                 "Old: #{article.base_rfc5646_locale}, New: #{@source_rfc5646_locale}")
      end

      article.targeted_rfc5646_locales = article.targeted_rfc5646_locales.merge(@target_rfc5646_locale => true)
    else
      article = @project.articles.build(name: unit.article_name,
                                        description: description,
                                        sections_hash: unit.sections_hash,
                                        base_rfc5646_locale: @source_rfc5646_locale,
                                        targeted_rfc5646_locales: { @target_rfc5646_locale => true })
    end
    unit.article = article
  end

  def remove_duplicate_translation_units(units)
    puts "Removing duplicates"
    units_hash = {}
    units.each do |unit|
      if !units_hash.key?(unit.article_name) || unit.timestamp > units_hash[unit.article_name].timestamp
        units_hash[unit.article_name] = unit
      end
    end
    puts "Removed #{units.size - units_hash.size} duplicates"
    units_hash.values
  end

  def remove_empty_translation_units(units)
    puts "Removing empty translation units"
    initial_count = units.size
    units = units.reject { |unit| unit.source_copy.blank? || unit.target_copy.blank? }
    puts "Removed #{initial_count - units.size} empties"
    units
  end

  def validate_articles!(articles)
    total_count = articles.count
    puts "Validating #{total_count} articles"
    articles.each_slice(100).with_index do |batch, i|
      puts "Still validating. Left: #{total_count - i*100}"
      batch.each do |article|
        unless article.valid?
          fail("Couldn't validate article: #{article.errors.full_messages}")
        end
      end
    end
  end

  def save_articles(articles)
    total_count = articles.count
    puts "Saving #{total_count} articles"
    articles.each_slice(100).with_index do |batch, i|
      puts "Still saving. Left: #{total_count - i*100}"
      batch.each(&:save)
    end
  end

  def wait_until_all_articles_are_loaded(articles)
    article_ids = articles.map(&:id)
    while (count = Article.where(id: article_ids).loading.count) > 0
      puts "Sleeping until all articles are loaded. #{count} left."
      sleep 1
    end
  end

  def add_translations(units)
    total_count = units.count
    puts "Adding translations"
    units.each_slice(100).with_index do |batch, i|
      puts "Still translating. Left: #{total_count - i*100}"
      batch.each do |unit|
        target_translations = unit.article.translations
                                  .not_translated
                                  .where(source_rfc5646_locale: @source_rfc5646_locale,
                                         rfc5646_locale:        @target_rfc5646_locale)

        if target_translations.length > 1
          puts("WARNING: Expected 1 target translation, found #{target_translations.length}. Article id: #{article.id}")
        elsif !target_translations.empty?
          target_translations.first.update copy: unit.target_copy,
                                           approved: true,
                                           preserve_reviewed_status: true
        end
      end
    end
  end

  def description
    @_description ||= "#{Time.now}: Imported from trados dump. " +
        "filepath: #{@filepath}, " +
        "project_id: #{@project.id}, " +
        "project_name: #{@project.name}, " +
        "source_rfc5646_locale: #{@source_rfc5646_locale}, " +
        "source_rfc5646_rep: #{@source_rfc5646_rep}, " +
        "target_rfc5646_locale: #{@target_rfc5646_locale}, " +
        "target_rfc5646_rep: #{@target_rfc5646_rep}."
  end

  def fail(msg)
    raise TradosImporter::Error, msg
  end

  class Error < StandardError
  end

  class TranslationUnit
    attr_reader :source_copy, :target_copy, :timestamp
    attr_accessor :article

    def initialize(source_copy, target_copy, timestamp_str)
      @source_copy = source_copy
      @target_copy = target_copy
      @timestamp = DateTime.parse(timestamp_str)
    end

    def article_name
      'trados-import ' + Digest::SHA1.hexdigest(@source_copy)
    end

    def sections_hash
      { 'body' => @source_copy}
    end
  end
end

namespace :trados do
  desc "Import from trados"
  task :import, [:filepath, :project_id, :project_name, :source_rfc5646_locale, :source_rfc5646_rep, :target_rfc5646_locale, :target_rfc5646_rep] => :environment do |t, args|
    log_suffix = '[trados:import]'
    start_time = Time.now
    puts "#{log_suffix} Attempting to import trados dump."

    begin
      TradosImporter.new(args[:filepath],
                         args[:project_id],
                         args[:project_name],
                         args[:source_rfc5646_locale],
                         args[:source_rfc5646_rep],
                         args[:target_rfc5646_locale],
                         args[:target_rfc5646_rep]
      ).import
    rescue TradosImporter::Error => msg
      puts "#{log_suffix} #{msg}."
      puts "#{log_suffix} Failed."
    else
      puts "#{log_suffix} Successfully imported trados dump."
    end

    puts "Took #{(Time.now - start_time).round} seconds."
  end
end
