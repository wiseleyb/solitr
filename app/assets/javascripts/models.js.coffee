# Immutable
class App.Models.Rank
  constructor: (@value) ->

  letter: ->
    'A23456789TJQK'[@value]
  nextLower: ->
    if value == 0 then null else App.Models.ranks[value - 1]
  nextHigher: ->
    if value == 12 then null else App.Models.ranks[value + 1]

# Immutable
class App.Models.Suit
  constructor: (@value) ->

  symbol: ->
    '♣♦♥♠'[@value]
  string: ->
    ['clubs', 'diamonds', 'hearts', 'spades'][@value]
  letter: ->
    ['CDHS'][@value]
  color: ->
    if _(['clubs', 'spades']).includes(@string()) then 'black' else 'red'

App.Models.ranks = (new App.Models.Rank(i) for i in [0...13])
App.Models.suits = (new App.Models.Suit(i) for i in [0...4])

_nextId = 0

class App.Models.Card
  constructor: (@rank, @suit) ->
    @id = _nextId++

  string: ->
    "#{@rank.letter()}#{@suit.symbol()}"

class App.Models.Tableau
  constructor: ->
    @downturnedCards = []
    @upturnedCards = []

#    accepts: (card) ->
#      if @upturnedCards.length == 0
#        return false unless @downturnedCards.length == 0
#        card.rank.letter() == 'K'
#      else
#        lastCard = _(@upturnedCards).last()
#        lastCard.rank.nextLower() == card.rank and
#          lastCard.color != card.color

class App.Models.GameState
  constructor: ->
    @tableaux = (new App.Models.Tableau for i in [0...7])
    @stock = []
    @waste = []
    @foundations = ([] for i in [0...4])

  deal: ->
    @deck = _(@createDeck()).shuffle()
    deckCopy = @deck.slice(0)
    for tableau, index in @tableaux
      for i in [0...index]
        tableau.downturnedCards.push(deckCopy.pop())
      tableau.upturnedCards.push(deckCopy.pop())
    while deckCopy.length
      @stock.push(deckCopy.pop())

  createDeck: ->
    _(new App.Models.Card(rank, suit) \
      for rank in App.Models.ranks \
      for suit in App.Models.suits).flatten()

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

  _getMoveCollection: (name) -> # 'stock' or ['tableaux', 1]
    c = if name instanceof Array then this[name[0]][name[1]] else this[name]
    if c instanceof App.Model.Tableau
      c = c.upturnedCards

class App.Models.Command
  direction: 'do' # default

  constructor: (attributes) ->
    _(this).extend(attributes)
