#= require underscore

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

  isKing: ->
    return @rank.value == 12 

  display: ->
    "#{@rank.letter()}#{@suit.letter()}"
  
  deepClone: ->
    res = JSON.parse(JSON.stringify(this))
    res.rank.letter = this.rank.letter()
    res.rank.nextLower = this.rank.nextLower()
    res.rank.nextHigher = this.rank.nextHigher()
    res.suit.letter = this.suit.letter()
    res.suit.color = this.suit.color()
    res.isKing = this.isKing()
    res.display = this.display()
    return res

class App.Models.Klondike
  cardsToTurn: null # override in subclass
  numberOfFoundations: 4
  numberOfTableauPiles: 7

  constructor: ->
    # Structure
    @faceUpTableauPiles = ([] for i in [0...@numberOfTableauPiles])
    @faceDownTableauPiles = ([] for i in [0...@numberOfTableauPiles])
    @stock = []
    @waste = []
    @foundations = ([] for i in [0...@numberOfFoundations])

    @undoStack = []

    # Locators
    @locators = {}
    @locators.foundations = (['foundations', i] for i in [0...@numberOfFoundations])
    @locators.faceDownTableauPiles = (['faceDownTableauPiles', i] for i in [0...@numberOfTableauPiles])
    @locators.faceUpTableauPiles = (['faceUpTableauPiles', i] for i in [0...@numberOfTableauPiles])
    @locators.all = [['stock'], ['waste'], @locators.foundations...,
      @locators.faceDownTableauPiles..., @locators.faceUpTableauPiles...]

    # for consistent cards and a solveable solution use
    # currently solves in 148 moves
    @deck = @createDeck() 
    # @deck = _(@createDeck()).shuffle()
    
  deal: ->
    deckCopy = @deck.slice(0)
    for i in [0...@faceDownTableauPiles.length]
      for j in [0...i]
        @faceDownTableauPiles[i].push(deckCopy.pop())
      @faceUpTableauPiles[i].push(deckCopy.pop())
    while deckCopy.length
      @stock.push(deckCopy.pop())

  createDeck: ->
    _(new App.Models.Card(rank, suit) \
      for rank in App.Models.ranks \
      for suit in App.Models.suits).flatten()

  foundationAccepts: (foundationIndex, cards) ->
    _assert cards instanceof Array
    return false if cards.length != 1
    topMostCard = _(@foundations[foundationIndex]).last()
    if topMostCard?
      topMostCard.rank.nextHigher() == cards[0].rank and \
        topMostCard.suit == cards[0].suit
    else
      cards[0].rank.letter() == 'A'

  tableauPileAccepts: (tableauPileIndex, cards) ->
    _assert cards instanceof Array
    topMostCard = _(@faceUpTableauPiles[tableauPileIndex]).last()
    if topMostCard
      topMostCard.rank.nextLower() == cards[0].rank and \
        topMostCard.suit.color() != cards[0].suit.color()
    else
      @faceDownTableauPiles[tableauPileIndex].length == 0 and \
        cards[0].rank.letter() == 'K'

  getCollection: (locator) ->
    if locator.length == 2
      this[locator[0]][locator[1]]
    else
      this[locator[0]]

  getLocator: (card) ->
    for locator in @locators.all
      return locator if _(@getCollection(locator)).include(card)
    null

  # If this card is movable, return an array containing this card and any cards
  # that would be moved with it. Else, return null.
  movedWithCard: (card) ->
    locator = @getLocator(card)
    _assert(locator?)
    collection = @getCollection(locator)
    switch locator[0]
      when 'waste', 'foundations'
        if collection.indexOf(card) == collection.length - 1
          [card]
        else
          null
      when 'faceUpTableauPiles'
        collection.slice(collection.indexOf(card))
      else
        null

  executeCommand: (cmd) ->
    @_assertStructure()
    @_assertCommand(cmd)
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
            @faceUpTableauPiles[cmd.tableauPileIndex].push(@faceDownTableauPiles[cmd.tableauPileIndex].pop())
          when 'turnStock'
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
            @faceDownTableauPiles[cmd.tableauPileIndex].push(@faceUpTableauPiles[cmd.tableauPileIndex].pop())
          when 'turnStock'
            for i in [0...cmd.cardsTurned]
              _assert @waste.length
              @stock.push(@waste.pop())
          when 'redeal'
            while @stock.length
              @waste.push(@stock.pop())
    @_assertStructure()

  nextAutoCommand: ->
    # If any facedown card can be flipped, flip it now
    for i in [0...@faceDownTableauPiles.length]
      if @faceDownTableauPiles[i].length > 0 and @faceUpTableauPiles[i].length == 0
        return new App.Models.Command
          action: 'flip'
          tableauPileIndex: i
          initiator: 'auto'
    # Auto-play when obviously won
    if @_isObviouslyWon()
      candidateLocators = (lo for lo in [['waste'], @locators.faceUpTableauPiles...] \
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
    for faceDownTableauPile in @faceDownTableauPiles
      return false if faceDownTableauPile.length > 0
    true

  isWon: ->
    for foundation in @foundations
      return false if _(foundation).last()?.rank.letter() != 'K'
    return true

  # Consistency checks

  _assertStructure: ->
    for arrayName in ['faceUpTableauPiles', 'faceDownTableauPiles', 'stock', 'waste', 'foundations']
      _assert this[arrayName] instanceof Array, "#{arrayName} is not an array", this[arrayName]
    for locator in @locators.all
      collection = @getCollection(locator)
      _assert collection, "collection not found", locator
      for card in collection
        _assert card instanceof App.Models.Card, "not a Card in collection", card, locator

  _assertCommand: (cmd) ->
    switch cmd.action
      when 'move'
        @_assertLocator(cmd.src)
        @_assertLocator(cmd.dest)
        _assert cmd.numberOfCards
        _assert cmd.dest[0] == 'faceUpTableauPiles' if cmd.numberOfCards > 1

  _assertLocator: (lo) -> _assert(1 <= lo.length <= 2)

  # Development helpers to load and save game states

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
