window.App ?= {}
App.Models ?= {}

# Immutable singleton
class App.Models.Rank
  constructor: (@value) ->

  letter: ->
    'A23456789TJQK'[@value]
  nextLower: ->
    if @value == 0 then null else App.Models.ranks[@value - 1]
  nextHigher: ->
    if @value == 12 then null else App.Models.ranks[@value + 1]

# Immutable singleton
class App.Models.Suit
  constructor: (@value) ->

  letter: ->
    'CDHS'.charAt(@value) # clubs, diamonds, hearts, spades
  color: ->
    if @letter() == 'C' or @letter() == 'S' then 'black' else 'red'

# Do not instantiate Rank and Suit; instead, use these:
App.Models.ranks = (new App.Models.Rank(i) for i in [0...13])
App.Models.suits = (new App.Models.Suit(i) for i in [0...4])

_nextId = 0

class App.Models.Card
  constructor: (@rank, @suit) ->
    @id = "id#{_nextId++}"

class App.Models.Klondike
  cardsToTurn: null # override in subclass
  numberOfFoundations: 4
  numberOfTableaux: 7

  constructor: ->
    # Structure
    @faceUpTableaux = ([] for i in [0...@numberOfTableaux])
    @faceDownTableaux = ([] for i in [0...@numberOfTableaux])
    @stock = []
    @waste = []
    @foundations = ([] for i in [0...@numberOfFoundations])

    @undoStack = []

    # Locators
    @locators = {}
    @locators.foundations = (['foundations', i] for i in [0...@numberOfFoundations])
    @locators.faceDownTableaux = (['faceDownTableaux', i] for i in [0...@numberOfTableaux])
    @locators.faceUpTableaux = (['faceUpTableaux', i] for i in [0...@numberOfTableaux])
    @locators.all = [['stock'], ['waste'], @locators.foundations...,
      @locators.faceDownTableaux..., @locators.faceUpTableaux...]

    @deck = _(@createDeck()).shuffle()

  # consistency check
  assertStructure: ->
    for arrayName in ['faceUpTableaux', 'faceDownTableaux', 'stock', 'waste', 'foundations']
      assert this[arrayName] instanceof Array, "#{arrayName} is not an array", this[arrayName]
    for locator in @locators.all
      collection = @getCollection(locator)
      assert collection, "collection not found", locator
      for card in collection
        assert card instanceof App.Models.Card, "not a Card in collection", card, locator

  deal: ->
    deckCopy = @deck.slice(0)
    for i in [0...@faceDownTableaux.length]
      for j in [0...i]
        @faceDownTableaux[i].push(deckCopy.pop())
      @faceUpTableaux[i].push(deckCopy.pop())
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
    topMostCard = _(@faceUpTableaux[tableauIndex]).last()
    if topMostCard
      topMostCard.rank.nextLower() == cards[0].rank and \
        topMostCard.suit.color() != cards[0].suit.color()
    else
      @faceDownTableaux[tableauIndex].length == 0 and \
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
        assert cmd.dest[0] == 'faceUpTableaux' if cmd.numberOfCards > 1
    # To do: We should check the legality of the command here, not just assert
    # that it is a valid command at all.
    true

  getLocator: (card) ->
    for locator in @locators.all
      return locator if _(@getCollection(locator)).include(card)
    null

  # If this card is movable, return an array containing this card and any cards
  # that would be moved with it. Else, return null.
  movedWithCard: (card) ->
    locator = @getLocator(card)
    assert(locator?)
    collection = @getCollection(locator)
    switch locator[0]
      when 'waste', 'foundations'
        if collection.indexOf(card) == collection.length - 1
          [card]
        else
          null
      when 'faceUpTableaux'
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
          when 'flip'
            @faceUpTableaux[cmd.tableauIndex].push(@faceDownTableaux[cmd.tableauIndex].pop())
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
          when 'flip'
            @faceDownTableaux[cmd.tableauIndex].push(@faceUpTableaux[cmd.tableauIndex].pop())
          when 'turn'
            for i in [0...cmd.cardsTurned]
              assert @waste.length
              @stock.push(@waste.pop())
          when 'redeal'
            while @stock.length
              @waste.push(@stock.pop())

  nextAutoCommand: ->
    # If any facedown card can be flipped, flip it now
    for i in [0...@faceDownTableaux.length]
      if @faceDownTableaux[i].length > 0 and @faceUpTableaux[i].length == 0
        return new App.Models.Command
          action: 'flip'
          tableauIndex: i
          initiator: 'auto'
    # Auto-play when obviously won
    if @_isObviouslyWon()
      candidateLocators = (lo for lo in [['waste'], @locators.faceUpTableaux...] \
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
    for faceDownTableau in @faceDownTableaux
      return false if faceDownTableau.length > 0
    true

  isWon: ->
    for foundation in @foundations
      return false if _(foundation).last()?.rank.letter() != 'K'
    return true

class App.Models.KlondikeTurnOne extends App.Models.Klondike
  cardsToTurn: 1

class App.Models.KlondikeTurnThree extends App.Models.Klondike
  cardsToTurn: 3

class App.Models.Command
  direction: 'do' # or: 'undo'
  initiator: 'user' # or: 'auto'

  constructor: (attributes) ->
    _(this).extend(attributes)

  createUndoCommand: ->
    _(_(this).clone()).extend(direction: 'undo')
