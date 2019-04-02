# Copyright 2018 Square Inc.
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
require 'awesome_print'

class AssetDocxImporter
  # @param [Fixnum] asset_id The ID of a Asset
  def import(asset_id)
    @asset = Asset.find(asset_id)
    @document = get_document(@asset.file)
    paragraphs = []
    @document.paragraphs.each_with_index do |paragraph, index|
      paragraphs << {
        node: paragraph.node,
        text: paragraph.text,
        background_color: paragraph.xpath('.//w:shd/@w:fill').first&.value,
        index: index
      }
    end
    cells = []
    @document.tables.each do |table|
      table.rows.each do |row|
        row.cells.each do |cell|
          cells << {
            node: cell.node,
            text: cell.text,
            background_color: cell.xpath('.//w:shd/@w:fill').first&.value
          }
        end
      end
    end

    # Paragraphs contain all table cells, but tables cells don't contain all paragraphs
    paragraphs.each do |paragraph|
      cell = cells.find { |c| c[:text] == paragraph[:text] }
      next unless cell

      paragraph[:background_color] = cell[:background_color] unless paragraph[:background_color]
      paragraph[:node] = cell[:node]
    end

    paragraphs.select! { |p| %w[fefb00 ffff00 fdfc00].include?(p[:background_color]) }
    paragraphs.each do |p|
      process_paragraph(p, p[:index])
    end
  end

  def get_document(file)
    Docx::Document.open(file.path)
  end

  def process_paragraph(paragraph, index)
    # check for hyperlinks
    hyperlink_text = paragraph[:node].xpath('.//w:instrText/text()')
    hyperlink = nil

    if hyperlink_text.text =~ /\"([^\"]+)\"/i
      hyperlink = $1
    end

    # for the paragraph, we must split into sentences
    sentences = paragraph[:text].split(/(?<!\w\.\w.)(?<![A-Z][a-z]\.)(?<=\.|\?)((?=[A-Z])|\s+)/)

    sentences.each_with_index do |sentence, sentence_index|
      next if sentence.blank?

      key_name = generate_key_name(index, sentence_index, sentence)
      key = Key.for_key(key_name).create_or_update!(
        project: @asset.project,
        key: key_name,
        source_copy: sentence,
        skip_readiness_hooks: true,
        ready: false,
        other_data: {
          url: hyperlink
        }
      )

      @asset.keys << key unless @asset.keys.include?(key)

      key.add_pending_translations(@asset)
    end
  end

  def generate_key_name(index, sentence_index, sentence)
    file_name = @asset.file_name.gsub(' ', '_').downcase
    hashed_value = Digest::SHA1.hexdigest(sentence)
    "#{file_name}-paragraph#{index}-sentence#{sentence_index}-#{hashed_value}"
  end
end
