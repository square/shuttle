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

class V8::Object
  def hash
    @context.enter do
      @context.to_ruby @native.GetIdentityHash()
    end
  end

  def to_hash(cache={})
    hsh = {}

    each do |k, v|
      if v.kind_of?(V8::Object)
        if cache[v.hash]
          v = cache[v.hash]
        else
          cache[v.hash] = v
        end
        hsh[k.to_s] = v.to_hash(cache)
      else
        hsh[k.to_s] = v
      end
    end
    hsh
  end
end
