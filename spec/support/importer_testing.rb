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

module ImporterTesting
  def test_importer(importer, content, path='foo/bar', locale=nil)
    importer.instance_variable_set :@file, Importer::Base::File.new(path, content, locale)
    importer.instance_variable_set :@keys, []
    receiver = Importer::Base::Receiver.new(importer, locale)
    importer.send :import_strings, receiver
  end
end
