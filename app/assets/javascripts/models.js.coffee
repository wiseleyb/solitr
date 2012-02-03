# Immutable
App.Models.Rank = Ember.Object.extend
  value: null

  letter: ->
    'A23456789TJQK'[@get 'value']
  nextLower: ->
    if value == 0 then null else App.Models.ranks[value - 1]
  nextHigher: ->
    if value == 12 then null else App.Models.ranks[value + 1]

# Immutable
App.Models.Suit = Ember.Object.extend
  value: null

  symbol: ->
    '♣♦♥♠'[@get 'value']
  string: ->
    ['clubs', 'diamonds', 'hearts', 'spades'][@get 'value']
  letter: ->
    ['CDHS'][@get 'value']
  color: ->
    if _(['clubs', 'spades']).includes(@string()) then 'black' else 'red'

App.Models.ranks = (App.Models.Rank.create(value: i) for i in [0...13])
App.Models.suits = (App.Models.Suit.create(value: i) for i in [0...4])

_nextId = 0

App.Models.Card = Ember.Object.extend
  id: (->
    @_id ?= _nextId++
    "id#{@_id}"
  ).property()
  rank: null
  suit: null

  string: ->
    "#{@get('rank').letter()}#{@get('suit').symbol()}"

App.Models.Card.ranks = [0...13]
App.Models.Card.suits = ['clubs', 'diamonds', 'hearts', 'spades']

App.Models.CardCollection = Ember.Object.extend
  init: ->
    @set('cards', [])

  pushCard: (card) ->
    assert card instanceof App.Models.Card
    @get('cards').pushObject(card)

  popCard: ->
    @get('cards').popObject(card)

  getLength: ->
    @get('cards').length

App.Models.Stock = App.Models.CardCollection.extend()
App.Models.Waste = App.Models.CardCollection.extend()
App.Models.Foundation = App.Models.CardCollection.extend()

App.Models.TableauPart = App.Models.CardCollection.extend()
App.Models.Tableau = Ember.Object.extend
  downturnedCards: null
  upturnedCards: null

  init: ->
    @set 'downturnedCards', App.Models.TableauPart.create()
    @set 'upturnedCards', App.Models.TableauPart.create()

  accepts: (card) ->
    if @get('upturnedCards').length == 0
      return false unless @get('downturnedCards').length == 0
      card.get('rank').letter() == 'K'
    else
      lastCard = _(@get('upturnedCards')).last()
      lastCard.get('rank').nextLower() == card.get('rank') and
        lastCard.get('color') != card.get('color')

App.Models.GameState = Ember.Object.extend
  tableaux: null
  stock: null
  waste: null
  foundations: null

  isValidCommand: (cmd) ->
    true
  #constructUndoCommand:
  executeCommand: (cmd) ->
    assert @isValidCommand(cmd)
    assert cmd.get('direction') == 'do', 'undo not implemented'
    switch cmd.get('action')
      when 'move'
        assert cmd.get('numberOfCards') == 1, 'not implemented'
        src = @_getMoveCollection(cmd.get 'src')
        dest = @_getMoveCollection(cmd.get 'dest')
        dest.push(src.pop())
      when 'upturn'
        tableau = @tableaux[cmd.get 'tableauIndex']
        tableau.upturnedCards.push(tableau.downturnedCards.pop())
      when 'turn'
        for i in [0...3]
          waste.push(stock.pop()) unless waste.length == 0
      when 'redeal'
        until stock.length == 0
          stock.push(waste.pop())

  _getMoveCollection: (name) -> # 'stock' or ['tableux', 1]
    c = if name instanceof Array then this[name[0]][name[1]] else this[name]
    if c instanceof App.Model.Tableau
      c = c.get('upturnedCards')

App.Models.GameState.createEmpty = ->
  App.Models.GameState.create
    tableaux: (App.Models.Tableau.create() for i in [0...7])
    stock: []
    waste: []
    foundations: ([] for i in [0...4])

App.Models.Command = Ember.Object.extend
  direction: 'do' # default
