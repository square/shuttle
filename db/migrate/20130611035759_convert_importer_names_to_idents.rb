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

class ConvertImporterNamesToIdents < ActiveRecord::Migration
  def up
    say_with_time "Converting Project importer path settings..." do
      Project.find_each do |project|
        project.skip_imports = project.skip_imports.reject(&:blank?).map { |i| i.constantize.ident }
        project.skip_importer_paths = project.skip_importer_paths.inject({}) do |hsh, (importer, val)|
          next unless importer.present?
          hsh[importer.constantize.ident] = val
        end
        project.only_importer_paths = project.only_importer_paths.inject({}) do |hsh, (importer, val)|
          next unless importer.present?
          hsh[importer.constantize.ident] = val
        end
        project.save!
      end
    end

    say_with_time "Converting Key data..." do
      Key.find_each do |key|
        key.importer = "Importer::#{key.importer}".constantize.ident
        key.save!
      end
    end
  end

  def down
    say_with_time "Converting Project importer path settings..." do
      Project.find_each do |project|
        project.skip_imports = project.skip_imports.reject(&:blank?).map { |i| Importer::Base.find_by_ident(importer).to_s }
        project.skip_importer_paths = project.skip_importer_paths.inject({}) do |hsh, (importer, val)|
          next unless importer.present?
          hsh[Importer::Base.find_by_ident(importer).to_s] = val
        end
        project.only_importer_paths = project.only_importer_paths.inject({}) do |hsh, (importer, val)|
          next unless importer.present?
          hsh[Importer::Base.find_by_ident(importer).to_s] = val
        end
        project.save!
      end
    end

    say_with_time "Converting Key data..." do
      Key.find_each do |key|
        key.importer = Importer::Base.find_by_ident(key.importer).to_s.demodulize
        key.save!
      end
    end
  end
end
