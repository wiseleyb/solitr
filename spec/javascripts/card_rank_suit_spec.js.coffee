#= require spec_helper
#= require models

suite 'Card', ->
  Card = App.Models.Card

  test 'id', ->
    neq new Card(0, 0, false).id, new Card(0, 0, false).id

  test 'rank, suit', ->
    c = new Card(App.Models.ranks[5], App.Models.suits[2])
    eq c.rank.value, 5
    eq c.suit.value, 2

suite 'Rank', ->
  Rank = App.Models.Rank

  test 'value', ->
    eq new Rank(5).value, 5

  test 'nextLower', ->
    assert.isNull new Rank(0).nextLower()
    eq new Rank(5).nextLower().value, 4
    eq new Rank(12).nextLower().value, 11

  test 'nextHigher', ->
    eq new Rank(0).nextHigher().value, 1
    eq new Rank(5).nextHigher().value, 6
    assert.isNull new Rank(12).nextHigher()

  test 'letter', ->
    eq new Rank(0).letter(), 'A'
    eq new Rank(1).letter(), '2'
    eq new Rank(8).letter(), '9'
    eq new Rank(9).letter(), 'T'
    eq new Rank(10).letter(), 'J'
    eq new Rank(11).letter(), 'Q'
    eq new Rank(12).letter(), 'K'

  test 'singletons', ->
    assert.deepEqual (r.value for r in App.Models.ranks), [0...13]

suite 'Suit', ->
  Suit = App.Models.Suit

  test 'value', ->
    eq new Suit(2).value, 2

  test 'letter', ->
    eq new Suit(0).letter(), 'C'
    eq new Suit(1).letter(), 'D'
    eq new Suit(2).letter(), 'H'
    eq new Suit(3).letter(), 'S'

  test 'color', ->
    eq new Suit(0).color(), 'black'
    eq new Suit(3).color(), 'black'
    eq new Suit(1).color(), 'red'
    eq new Suit(2).color(), 'red'

  test 'singletons', ->
    assert.deepEqual (s.value for s in App.Models.suits), [0...4]
