class RekeyAndroidStrings < ActiveRecord::Migration
  def up
    Commit.includes(:project).find_each do |commit|
      say "Processing commit ##{commit.id} (#{commit.project.name} #{commit.revision})..."

      # first store all the keys that used to be associated with this commit
      old_keys = commit.keys.includes(translations: :translation_changes).to_a

      # reimport the commit to get potentially new android strings
      say "Re-importing...", true
      begin
        commit.import_strings force: true, inline: true
      rescue => err
        say "Skipping: #{err.to_s}", true
        next
      end

      # match old keys to new keys and update translations as necessary
      say "Recombobulating translations from old keys...", true
      commit.reload.keys.where(ready: false).includes(:translations).each do |new_key|
        next unless new_key.importer == 'android'

        new_key_string = new_key.key.split(':').last
        blob_sha       = cached_blob_sha(new_key.project, commit.revision, new_key.source[1..-1])
        xml            = cached_blob_xml(new_key.project, blob_sha)
        tag            = find_new_key(xml, new_key_string)
        old_key_string = old_key(tag)

        old_key = old_keys.detect { |k| k.key == "#{new_key.source}:#{old_key_string}" }
        unless old_key
          say "[#{new_key.source}] Skipping #{new_key_string}; couldn't find corresponding #{old_key_string}", true
          next
        end

        old_key.translations.each do |old_translation|
          new_translation = new_key.translations.detect { |t| t.rfc5646_locale = old_translation.rfc5646_locale }
          next if new_translation.nil? || new_translation.translated?
          new_translation.copy          = old_translation.copy
          new_translation.approved      = old_translation.approved
          new_translation.translator_id = old_translation.translator_id
          new_translation.reviewer_id   = old_translation.reviewer_id
          new_translation.save!

          new_translation.translation_changes.delete_all
          old_translation.translation_changes.each do |tc|
            new_translation.translation_changes.create!(user: tc.user, diff: tc.diff)
          end
        end
      end
    end

    obsolete_keys = select_values("SELECT id FROM keys WHERE id NOT IN (SELECT key_id FROM commits_keys)")
    say "Deleting #{obsolete_keys.size} obsolete keys..."
    Key.where(id: obsolete_keys).destroy_all
  end

  def down
    Commit.includes(:project).find_each do |commit|
      say "Processing commit ##{commit.id} (#{commit.project.name} #{commit.revision})..."

      # first store all the keys that used to be associated with this commit
      old_keys = commit.keys.includes(translations: :translation_changes).to_a

      # reimport the commit to get potentially new android strings
      say "Re-importing...", true
      begin
        commit.import_strings force: true, inline: true
      rescue => err
        say "Skipping: #{err.to_s}", true
        next
      end

      # match old keys to new keys and update translations as necessary
      say "Recombobulating translations from old keys...", true
      commit.reload.keys.where(ready: false).includes(:translations).each do |new_key|
        next unless new_key.importer == 'android'

        new_key_string = new_key.key.split(':').last
        blob_sha       = cached_blob_sha(new_key.project, commit.revision, new_key.source[1..-1])
        xml            = cached_blob_xml(new_key.project, blob_sha)
        tag            = find_old_key(xml, new_key_string)
        old_key_string = new_key(tag)

        old_key = old_keys.detect { |k| k.key == "#{new_key.source}:#{old_key_string}" }
        unless old_key
          say "[#{new_key.source}] Skipping #{new_key_string}; couldn't find corresponding #{old_key_string}", true
          next
        end

        old_key.translations.each do |old_translation|
          new_translation = new_key.translations.detect { |t| t.rfc5646_locale = old_translation.rfc5646_locale }
          next if new_translation.nil? || new_translation.translated?
          new_translation.copy          = old_translation.copy
          new_translation.approved      = old_translation.approved
          new_translation.translator_id = old_translation.translator_id
          new_translation.reviewer_id   = old_translation.reviewer_id
          new_translation.save!

          new_translation.translation_changes.delete_all
          old_translation.translation_changes.each do |tc|
            new_translation.translation_changes.create!(user: tc.user, diff: tc.diff)
          end
        end
      end
    end

    obsolete_keys = select_values("SELECT id FROM keys WHERE id NOT IN (SELECT key_id FROM commits_keys")
    say "Deleting #{obsolete_keys.size} obsolete keys..."
    Key.where(id: obsolete_keys).destroy_all
  end

  private

  def old_key(tag)
    tag.path
  end

  def find_old_key(xml, key)
    xml.xpath(key).first
  end

  def new_key(tag)
    case tag.name
      when 'string'
        tag['name']
      when 'item'
        if tag['quantity']
          "#{tag.parent['name']}:#{tag['quantity']}"
        else
          index = tag.parent.css('item').index(tag)
          "#{tag.parent['name']}:#{index}"
        end
      else
        raise "Unknown key #{tag.name}: #{tag.to_s}"
    end
  end

  def find_new_key(xml, key)
    case key
      when /^(\w+)\[(\d+)\]$/
        tag = xml.css("string-array[name=#{$1}]").first
        tag.css('item')[$2.to_i]
      when /^(\w+)\[(\w+)\]$/
        tag = xml.css("plurals[name=#{$1}]").first
        tag.css("item[quantity=#{$2}]").first
      else
        xml.css("string[name=#{key}]").first
    end
  end

  def cached_blob_sha(project, revision, path)
    Rails.cache.fetch("cached_blob_sha:#{project.id}:#{revision}:#{path}") do
      project.repo.object("#{revision}^{tree}:#{path}").sha
    end
  end

  def cached_blob_xml(project, sha)
    Rails.cache.fetch("cached_blob_xml:#{project.id}:#{sha}") do
      Nokogiri::XML(project.repo.object(sha).contents)
    end
  end
end
