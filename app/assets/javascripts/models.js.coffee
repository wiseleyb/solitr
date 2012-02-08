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
    if @string() == 'clubs' or @string() == 'spades' then 'black' else 'red'

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
    # Rules
    @cardsToTurn = 3
    @numberOfFoundations = 4
    @numberOfTableaux = 7

    # Structure
    @upturnedTableaux = ([] for i in [0...@numberOfTableaux])
    @downturnedTableaux = ([] for i in [0...@numberOfTableaux])
    @stock = []
    @waste = []
    @foundations = ([] for i in [0...@numberOfFoundations])

    @undoStack = []

    # Helpers
    @locators = {}
    @locators.foundations = (['foundations', i] for i in [0...@numberOfFoundations])
    @locators.downturnedTableaux = (['downturnedTableaux', i] for i in [0...@numberOfTableaux])
    @locators.upturnedTableaux = (['upturnedTableaux', i] for i in [0...@numberOfTableaux])
    @locators.all = [['stock'], ['waste'], @locators.foundations...,
      @locators.downturnedTableaux..., @locators.upturnedTableaux...]

    @deck = _(@createDeck()).shuffle()

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
    deckCopy = @deck.slice(0)
    for i in [0...@downturnedTableaux.length]
      for j in [0...i]
        @downturnedTableaux[i].push(deckCopy.pop())
      @upturnedTableaux[i].push(deckCopy.pop())
    while deckCopy.length
      @stock.push(deckCopy.pop())

  dumpHash: ->
    hash = {}
    for locator in @locators.all
      hash[locator] = for card in @getCollection(locator)
        [card.rank.value, card.suit.value]
    hash['undoStack'] = @undoStack
    hash

  loadHash: (hash) ->
    deckCopy = @deck.slice(0)
    for locator in @locators.all
      @getCollection(locator).length = 0
      for [rank, suit] in hash[locator]
        card = _(deckCopy).find (c) =>
          c.rank.value == rank and c.suit.value == suit
        @getCollection(locator).push(card)
        deckCopy.splice(_(deckCopy).indexOf(card), 1)
    @undoStack = hash['undoStack']
    for list in @undoStack
      for cmd in list
        cmd.__proto__ = App.Models.Command

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

  getCollection: (locator) ->
    if locator.length == 2
      this[locator[0]][locator[1]]
    else
      this[locator[0]]

  _assertLocator: (lo) -> assert(1 <= lo.length <= 2)

  isLegalCommand: (cmd) ->
    switch cmd.action
      when 'move'
        @_assertLocator(cmd.src)
        @_assertLocator(cmd.dest)
        assert cmd.numberOfCards
        assert cmd.dest[0] == 'upturnedTableaux' if cmd.numberOfCards > 1
    true

  getLocator: (card) ->
    for locator in @locators.all
      return locator if _(@getCollection(locator)).include(card)
    null

  # If this card is movable, return an array containing this card and any cards
  # that would be moved with it. Else, return null.
  movableCards: (card) ->
    locator = @getLocator(card)
    assert(locator?)
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
    assert @isLegalCommand(cmd)
    switch cmd.direction
      when 'do'
        undoCommand = cmd.createUndoCommand()
        switch cmd.action
          when 'move'
            src = @getCollection(cmd.src)
            dest = @getCollection(cmd.dest)
            dest.push(src.slice(-cmd.numberOfCards)...)
            src.pop() for i in [0...cmd.numberOfCards] # seriously?
          when 'upturn'
            @upturnedTableaux[cmd.tableauIndex].push(@downturnedTableaux[cmd.tableauIndex].pop())
          when 'turn'
            undoCommand.cardsTurned = 0
            while undoCommand.cardsTurned < @cardsToTurn and @stock.length > 0
              @waste.push(@stock.pop())
              undoCommand.cardsTurned++
          when 'redeal'
            while @waste.length
              @stock.push(@waste.pop())
        @undoStack.push([]) unless cmd.initiator == 'auto'
        _(@undoStack).last().push(undoCommand)
      when 'undo'
        switch cmd.action
          when 'move'
            src = @getCollection(cmd.src)
            dest = @getCollection(cmd.dest)
            src.push(dest.slice(-cmd.numberOfCards)...)
            dest.pop() for i in [0...cmd.numberOfCards] # seriously?
          when 'upturn'
            @downturnedTableaux[cmd.tableauIndex].push(@upturnedTableaux[cmd.tableauIndex].pop())
          when 'turn'
            for i in [0...cmd.cardsTurned]
              assert @waste.length
              @stock.push(@waste.pop())
          when 'redeal'
            while @stock.length
              @waste.push(@stock.pop())

  nextAutoCommand: ->
    for i in [0...@downturnedTableaux.length]
      if @downturnedTableaux[i].length > 0 and @upturnedTableaux[i].length == 0
        return new App.Models.Command
          action: 'upturn'
          tableauIndex: i
          initiator: 'auto'
    if @_isObviouslyWon()
      candidateLocators = (lo for lo in [['waste'], @locators.upturnedTableaux...] \
                           when @getCollection(lo).length > 0)
      srcLocator = _(candidateLocators).min (lo) => _(@getCollection(lo)).last().rank.value
      if srcLocator
        for i in [0...@numberOfFoundations]
          if @foundationAccepts(i, [_(@getCollection(srcLocator)).last()])
            return new App.Models.Command
              action: 'move'
              src: srcLocator
              dest: ['foundations', i]
              numberOfCards: 1
              initiator: 'auto'
    null

  _isObviouslyWon: ->
    return false if @stock.length > 0 or @waste.length > 1
    for downturnedTableau in @downturnedTableaux
      return false if downturnedTableau.length > 0
    true

  isWon: ->
    for foundation in @foundations
      return false if _(foundation).last()?.rank.letter() != 'K'
    return true

class App.Models.Command
  direction: 'do' # or: 'undo'
  initiator: 'user' # or: 'auto'

  constructor: (attributes) ->
    _(this).extend(attributes)

  createUndoCommand: ->
    _(_(this).clone()).extend(direction: 'undo')
