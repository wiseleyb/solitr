# Immutable
class App.Models.Rank
  constructor: (@value) ->

  letter: ->
    'A23456789TJQK'[@value]
  nextLower: ->
    if @value == 0 then null else App.Models.ranks[@value - 1]
  nextHigher: ->
    if @value == 12 then null else App.Models.ranks[@value + 1]

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
    if _(['clubs', 'spades']).include(@string()) then 'black' else 'red'

App.Models.ranks = (new App.Models.Rank(i) for i in [0...13])
App.Models.suits = (new App.Models.Suit(i) for i in [0...4])

_nextId = 0

class App.Models.Card
  constructor: (@rank, @suit) ->
    @id = "id#{_nextId++}"

  string: ->
    "#{@rank.letter()}#{@suit.symbol()}"

class App.Models.GameState

  constructor: ->
    @numberOfFoundations = 4
    @numberOfTableaux = 7
    @upturnedTableaux = ([] for i in [0...@numberOfTableaux])
    @downturnedTableaux = ([] for i in [0...@numberOfTableaux])
    @stock = []
    @waste = []
    @foundations = ([] for i in [0...@numberOfFoundations])
    @locators = {}
    @locators.foundations = (['foundations', i] for i in [0...@numberOfFoundations])
    @locators.downturnedTableaux = (['downturnedTableaux', i] for i in [0...@numberOfTableaux])
    @locators.upturnedTableaux = (['upturnedTableaux', i] for i in [0...@numberOfTableaux])
    @locators.all = [['stock'], ['waste'], @locators.foundations...,
      @locators.downturnedTableaux..., @locators.upturnedTableaux...]

  # consistency check
  assertStructure: ->
    for arrayName in ['upturnedTableaux', 'downturnedTableaux', 'stock', 'waste', 'foundations']
      assert this[arrayName] instanceof Array, "#{arrayName} is not an array", this[arrayName]
    for locator in @locators.all
      collection = @getCollection(locator)
      assert collection, "collection not found", locator
      for card in collection
        assert card instanceof App.Models.Card, "not a Card in collection", card, locator

  deal: ->
    @deck = _(@createDeck()).shuffle()
    deckCopy = @deck.slice(0)
    for i in [0...@downturnedTableaux.length]
      for j in [0...i]
        @downturnedTableaux[i].push(deckCopy.pop())
      @upturnedTableaux[i].push(deckCopy.pop())
    while deckCopy.length
      @stock.push(deckCopy.pop())

  createDeck: ->
    _(new App.Models.Card(rank, suit) \
      for rank in App.Models.ranks \
      for suit in App.Models.suits).flatten()

  foundationAccepts: (foundationIndex, cards) ->
    assert cards instanceof Array
    return false if cards.length != 1
    topMostCard = _(@foundations[foundationIndex]).last()
    if topMostCard?
      topMostCard.rank.nextHigher() == cards[0].rank and \
        topMostCard.suit == cards[0].suit
    else
      cards[0].rank.letter() == 'A'

  tableauAccepts: (tableauIndex, cards) ->
    assert cards instanceof Array
    topMostCard = _(@upturnedTableaux[tableauIndex]).last()
    if topMostCard
      topMostCard.rank.nextLower() == cards[0].rank and \
        topMostCard.suit.color() != cards[0].suit.color()
    else
      @downturnedTableaux[tableauIndex].length == 0 and \
        cards[0].rank.letter() == 'K'

  isValidCommand: (cmd) ->
    true

  getCollection: (locator) ->
    if locator.length == 2
      this[locator[0]][locator[1]]
    else
      this[locator[0]]

#    validCommand: (cmd) ->
#      switch cmd.action
#        when 'move'
#          assert cmd.numberOfCards == 1, 'not implemented'
#          return false unless cmd.src
#          srcCard = _(@getCollection(cmd.src)).last()
#          return false unless srcCard?

  getLocator: (card) ->
    for locator in @locators.all
      return locator if _(@getCollection(locator)).include(card)
    null

  # If this card is movable, return an array containing this card and any cards
  # that would be moved with it. Else, return null.
  movableCards: (card) ->
    locator = @getLocator(card)
    assert(locator)
    collection = @getCollection(locator)
    switch locator[0]
      when 'waste', 'foundations'
        if collection.indexOf(card) == collection.length - 1
          [card]
        else
          null
      when 'upturnedTableaux'
        collection.slice(collection.indexOf(card))
      else
        null

  executeCommand: (cmd) ->
    assert @isValidCommand(cmd)
    assert cmd.direction == 'do', 'undo not implemented'
    switch cmd.action
      when 'move'
        assert cmd.numberOfCards == 1, 'not implemented'
        src = @getCollection(cmd.src)
        dest = @getCollection(cmd.dest)
        dest.push(src.pop())
      when 'upturn'
        @upturnedTableaux[cmd.tableauIndex].push(@downturnedTableaux[cmd.tableauIndex].pop())
      when 'turn'
        for i in [0...3]
          @waste.push(@stock.pop()) unless @stock.length == 0
      when 'redeal'
        while @waste.length
          @stock.push(@waste.pop())

  nextAutoCommand: ->
    for i in [0...@downturnedTableaux.length]
      if @downturnedTableaux[i].length > 0 and @upturnedTableaux[i].length == 0
        return new App.Models.Command
          action: 'upturn'
          tableauIndex: i
    null

class App.Models.Command
  direction: 'do' # default

  constructor: (attributes) ->
    _(this).extend(attributes)
