#= require spec_helper
#= require models

suite 'Klondike', ->
  k1 = new App.Models.KlondikeTurnOne

  test 'constructor', ->

  test 'deal', ->

  test 'createDeck', ->
    d = k1.createDeck()
    eq d.length, 52
