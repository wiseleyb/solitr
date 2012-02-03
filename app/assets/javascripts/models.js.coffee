# Immutable
App.Models.Rank = Ember.Object.extend
  value: null

  letter: ->
    'A23456789TJQK'[@value]
  nextLower: ->
    if value == 0 then null else App.Models.ranks[value - 1]
  nextHigher: ->
    if value == 12 then null else App.Models.ranks[value + 1]

# Immutable
App.Models.Suit = Ember.Object.extend
  value: null

  symbol: ->
    '♣♦♥♠'[@value]
  string: ->
    ['clubs', 'diamonds', 'hearts', 'spades'][@value]
  letter: ->
    ['CDHS'][@value]
  color: ->
    if _(['clubs', 'spades']).includes(@string()) then 'black' else 'red'

App.Models.ranks = (App.Models.Rank.create(value: i) for i in [0...13])
App.Models.suits = (App.Models.Suit.create(value: i) for i in [0...4])

_nextId = 0

App.Models.Card = Ember.Object.extend
  init: ->
    @id = _nextId++
  rank: null
  suit: null

  string: ->
    "#{@rank.letter()}#{@suit.symbol()}"

App.Models.CardCollection = Ember.Object.extend
  init: ->
    @cards = []

  pushCard: (card) ->
    assert card instanceof App.Models.Card
    @cards.pushObject(card)

  popCard: ->
    @cards.popObject(card)

  getLength: ->
    @cards.length

App.Models.Stock = App.Models.CardCollection.extend()
App.Models.Waste = App.Models.CardCollection.extend()
App.Models.Foundation = App.Models.CardCollection.extend()

App.Models.TableauPart = App.Models.CardCollection.extend()
App.Models.Tableau = Ember.Object.extend
  downturnedCards: null
  upturnedCards: null

  init: ->
    @downturnedCards = App.Models.TableauPart.create()
    @upturnedCards = App.Models.TableauPart.create()

  accepts: (card) ->
    if @upturnedCards.length == 0
      return false unless @downturnedCards.length == 0
      card.rank.letter() == 'K'
    else
      lastCard = _(@upturnedCards).last()
      lastCard.rank.nextLower() == card.rank and
        lastCard.color != card.color

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
    assert cmd.direction == 'do', 'undo not implemented'
    switch cmd.action
      when 'move'
        assert cmd.numberOfCards == 1, 'not implemented'
        src = @_getMoveCollection(cmd.src)
        dest = @_getMoveCollection(cmd.dest)
        dest.push(src.pop())
      when 'upturn'
        tableau = @tableaux[cmd.tableauIndex]
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
      c = c.upturnedCards

App.Models.GameState.createEmpty = ->
  App.Models.GameState.create
    tableaux: (App.Models.Tableau.create() for i in [0...7])
    stock: []
    waste: []
    foundations: ([] for i in [0...4])

App.Models.Command = Ember.Object.extend
  direction: 'do' # default
