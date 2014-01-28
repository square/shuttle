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

# We need to memoize the values returned by the let functions,
# but only for the current spec. This will ensure that all registered
# lets do not have an already-memoized value.
clearMemoizedLets = (suite) ->
  if suite.parentSuite
    clearMemoizedLets suite.parentSuite

  if suite.lets_
    for own name, getter of suite.lets_
      delete getter.memoizedValue

# This defines getters on the spec named by the let calls.
defineGettersOnSpec = (spec, suite) ->
  if suite.parentSuite
    defineGettersOnSpec spec, suite.parentSuite

  for own name, getter of suite.lets_
    spec.__defineGetter__ name, getter

# Global beforeEach to clear memoized values.
beforeEach ->
  clearMemoizedLets @suite

withRunLoop = Ember?.run? or (fn) -> fn()

# Defines an overridable getter on all specs in this Suite.
jasmine.Suite.prototype.let = (name, getter) ->
  lets = (@lets_ ||= {})

  if typeof getter is 'function'
    # getter function, wrap it to memoize
    lets[name] = ->
      return lets[name].memoizedValue if 'memoizedValue' of lets[name]
      value = withRunLoop => getter.call(this)
      lets[name].memoizedValue = value
  else
    # constant, no need to memoize
    lets[name] = -> getter

jasmine.Suite.prototype.set = (name, getter) ->
  @let name, getter
  beforeEach -> @[name]

jasmine.Suite.prototype.helper = (name, helper) ->
  @let name, -> helper

# Hook into spec declaration that lets us define let getters on them.
jasmine_Suite_prototype_add = jasmine.Suite.prototype.add
jasmine.Suite.prototype.add = (spec, args...) ->
  defineGettersOnSpec spec, this
  jasmine_Suite_prototype_add.call(this, spec, args...)


## EXAMPLES

describe 'jasmine.Suite#let', ->
  @let 'name', -> 'Bob'

  it 'creates a property on the spec with the right name', ->
    expect(@name).toEqual('Bob')

  describe 'with a sub-suite', ->
    @let 'name', -> 'Joe'

    it 'allows overriding the parent suite value', ->
      expect(@name).toEqual('Joe')

  describe 'with a dependent value', ->
    @let 'person', -> {@name, @age}

    it 'allows chaining let value', ->
      expect(@person.name).toEqual('Bob')

    it 'allows chaining normal property values', ->
      @age = 20
      expect(@person.age).toEqual(20)


describe 'jasmine.Suite#set', ->
  setName = null
  letName = null

  @set 'setName', -> setName
  @let 'letName', -> letName

  it 'reads the value before running the spec', ->
    setName = 'Joy'
    letName = 'Joy'

    expect(@setName).toBeNull()
    expect(@letName).toEqual('Joy')


describe 'jasmine.Suite#helper', ->
  @helper 'addNumbers', (a, b) -> a + b

  it 'creates a property that contains the helper function', ->
    expect(typeof @addNumbers).toEqual('function')

  it 'allows calling the function', ->
    expect(@addNumbers 1, 2).toEqual(3)

  describe 'with a sub-suite', ->
    @helper 'addNumbers', (a, b) -> a + a

    it 'allows overriding the parent suite value', ->
      expect(@addNumbers 1, 2).toEqual(2)

  describe 'with lets', ->
    @let 'a', 1
    @let 'b', 2
    @helper 'addNumbers', -> @a + @b

    it 'can interact with let values', ->
      expect(@addNumbers()).toEqual(3)
