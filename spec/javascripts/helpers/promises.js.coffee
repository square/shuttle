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

expectPromise = (promise) ->
  new PromiseExpectation(promise)

promiseResolutionPlaceholder = {}

class PromiseExpectation
  constructor: (@promise) ->

  toResolve: ->
    resolved = no

    runs =>
      @promise.then -> resolved = yes

    waitsFor =>
      resolved
    , "expected #{@promise} to resolve but it did not"

  toResolveWith: (expected) ->
    actual = promiseResolutionPlaceholder

    runs =>
      @promise.then (result) -> actual = result

    waitsFor =>
      actual isnt promiseResolutionPlaceholder
    , "expected #{@promise} to resolve but it did not"

    runs =>
      expect(actual).toEqual(expected)

@expectPromise = expectPromise
