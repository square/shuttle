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

require 'mime/types'

# OK, so in Rails, we have Mime::Type and MIME::Type. Mime::Type is used by
# ActionController::Responder, and MIME::Type is used by the exporter as it can
# convert a MIME type into a file extension. Also unfortunately, each of them
# has a different subset of predefined assignments, and sometimes conflicting
# assignments as well.
#
# In general MIME::Type has the more comprehensive list of types. To fix this,
# we are going to register some of the MIME types we use with Mime::Type, fix up
# some of the conflicting definitions, and add some Shuttle-specific aliases.

# Mime::Type does not have the gzip assignment; MIME::Type does
Mime::Type.register 'application/x-gzip', :gz, [], %w(tgz)
Mime::Type.register_alias 'application/x-gzip', :ios

Mime::Type.register_alias 'text/plain', :strings

# Neither gem knows of the .properties assignment
properties = MIME::Type.new('application/x-java-properties') do |t|
  t.encoding   = '8bit'
  t.extensions = %w(properties)
end
MIME::Types.add properties
Mime::Type.register 'application/x-java-properties', :properties, [], %w(properties)

# Mime::Type does not have the Ruby assignment; MIME::Type does
Mime::Type.register 'application/x-ruby', :rb, [], %w(rbw)

# Nor does Mime::Type have the RTF assignment
Mime::Type.register 'text/rtf', :rtf, %w(application/rtf text/x-rtf application/x-rtf), []
Mime::Type.register_alias 'text/rtf', :trados

# MIME::Type calls it text/x-yaml, Mime::Type calls it application/x-yaml or text/yaml
# sigh...
Mime::Type.register 'text/x-yaml', :yaml, [], %w(yml)

# Mime::Type uses the obsolete text/javascript; MIME::Type uses the correct application/javascript
Mime::Type.unregister :js
Mime::Type.register 'application/javascript', :js, %w(text/javascript application/x-javascript), []

# For dependency-injected JavaScript
#TODO this should really be an option passed to the .js URL
Mime::Type.register_alias 'application/javascript', :jsm
