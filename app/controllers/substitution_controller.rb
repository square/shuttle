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

# Controller for performing substitution with the {WordSubstitutor}.

class SubstitutionController < ApplicationController
  rescue_from(WordSubstitutor::NoDictionaryError) do
    respond_to do |format|
      format.any { head :unprocessable_entity }
    end
  end

  # Returns the substitution of a string from a given locale to a given locale.
  #
  # Routes
  # ------
  #
  # `GET /substitute`
  #
  # Query Parameters
  # ----------------
  #
  # |          |                                               |
  # |:---------|:----------------------------------------------|
  # | `string` | The string to convert.                        |
  # | `from`   | The RFC 5646 locale of `string`.              |
  # | `to`     | The RFC 5646 locale to convert the string to. |
  #
  # Response
  # --------
  #
  # Returns a JSON-encoded {WordSubstitutor::Result} object.

  def convert
    from = Locale.from_rfc5646(params[:from])
    to   = Locale.from_rfc5646(params[:to])

    return head(:not_found) unless from && to
    return head(:bad_request) unless params[:string].kind_of?(String)

    substitutor = WordSubstitutor.new(from, to)

    respond_to do |format|
      format.json { render json: substitutor.substitutions(params[:string]) }
    end
  end
end
