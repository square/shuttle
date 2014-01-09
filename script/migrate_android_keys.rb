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

def migrate(commit, delete_old_keys=false)
  say "Processing commit ##{commit.id} (#{commit.project.name} #{commit.revision})..."

  # first store all the keys that used to be associated with this commit
  old_keys = commit.keys.includes(translations: :translation_changes).to_a

  # reimport the commit to get potentially new android strings
  say "Re-importing...", true
  commit.import_strings force: true, inline: true

  # match old keys to new keys and update translations as necessary
  say "Recombobulating translations from old keys...", true
  commit.reload.keys.includes(:translations).each do |new_key|
    next unless new_key.importer == 'android'

    new_key_string = new_key.key.split(':').last
    blob_sha       = cached_blob_sha(new_key.project, commit.revision, new_key.source[1..-1])
    xml            = Nokogiri::XML(cached_blob_contents(new_key.project, blob_sha))
    tag            = find_new_key(xml, new_key_string)
    old_key_string = old_key(tag)

    old_key = old_keys.detect { |k| k.key == "#{new_key.source}:#{old_key_string}" }
    unless old_key
      say "[#{new_key.source}] Skipping #{new_key_string}; couldn't find corresponding #{old_key_string}", true
      next
    end

    old_key.translations.each do |old_translation|
      next if old_translation.rfc5646_locale == commit.project.base_rfc5646_locale

      new_translation = new_key.translations.detect { |t| t.rfc5646_locale == old_translation.rfc5646_locale }
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

  if delete_old_keys
    say "Destroying old keys...", true
    Key.where(id: old_keys.map(&:id)).destroy_all
  end
end

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

def cached_blob_contents(project, sha)
  Rails.cache.fetch("cached_blob_contents:#{project.id}:#{sha}") do
    project.repo.object(sha).contents
  end
end

def say(msg, sub=false)
  print ' -> ' if sub
  puts msg
end

commit = Commit.for_revision(ARGV.first).first
delete_old_keys = (ARGV.last == 'delete')
migrate commit, delete_old_keys
