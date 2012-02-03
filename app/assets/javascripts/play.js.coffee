#= require_self
#= require models

class App.CardController
  constructor: (@model) ->
    @element = null

  # Eventually this should just save the parameters as a "resting position" and
  # let the visual updating be handled by animation code.
  setPosition: (left, top, zIndex, upturned) ->
    $(@element).css
      left: "#{left}px"
      top: "#{top}px"
      zIndex: zIndex
    @setUpturned(upturned)

  show: ->
    $(@element).show()

  setUpturned: (upturned) ->
    if upturned
      $(@element).css backgroundPosition: "-#{@model.rank.value * 79}px -#{_(['clubs', 'diamonds', 'hearts', 'spades']).indexOf(@model.suit.string()) * 123}px"
    else
      $(@element).css backgroundPosition: "-#{2 * 79}px -#{4 * 123}px"

  appendTo: (rootElement) ->
    @element = document.createElement('div')
    @element.className = 'card'
    @element.id = @model.id
    @setUpturned(false)
    $(rootElement).append($(@element))

class App.GameController
  gameState: null

  constructor: ->
    @cardControllers = {} # map IDs to views
    @element = $(App.rootElement)[0]
    @positions = @calculatePositions()

  calculatePositions: () ->
    firstColumn = 20
    columnOffset = 100
    firstRow = 20
    secondRow = 250
    {
      undealtCards: [0, 0]
      stock: [firstColumn, firstRow]
      waste: [firstColumn + columnOffset, firstRow]
      foundations: ([firstColumn + (3 + i) * columnOffset, firstRow] for i in [0...3])
      tableaux: ([firstColumn + i * columnOffset, secondRow] for i in [0...7])
      fanningOffset: 20
    }

  getCardController: (card) ->
    @cardControllers[card.id]

  initialGameState: ->
    @gameState = new App.Models.GameState
    @gameState.deal()
    # Initialize card controllers
    for card in @gameState.deck
      @cardControllers[card.id] = cardController = new App.CardController(card)
      cardController.appendTo(@element)
    @animateAfterCommand('deal')
    cardController.show() for id, cardController of @cardControllers
    @updateEventHandlers()

  processCommand: (cmd) ->
    @gameState.executeCommand(cmd)
    @animateAfterCommand(cmd)

  animateAfterCommand: (cmd) ->
    zIndex = 0
    for card in @gameState.stock.cards
      @getCardController(card).setPosition @positions.stock..., zIndex++, false
    for card in @gameState.waste.cards
      @getCardController(card).setPosition @positions.waste..., zIndex++, true
    for foundation, index in @gameState.foundations
      for card in foundation.cards
        @getCardController(card).setPosition @positions.foundations[index]..., zIndex++, true
    for tableau, index in @gameState.tableaux
      [left, top] = @positions.tableaux[index]
      offset = 0
      for card in tableau.downturnedCards.cards
        @getCardController(card).setPosition left, top + offset, zIndex++, false
        offset += @positions.fanningOffset
      for card in tableau.upturnedCards.cards
        @getCardController(card).setPosition left, top + offset, zIndex++, true
        offset += @positions.fanningOffset

  updateEventHandlers: ->
    $(@element).off()
#      if @gameState.stock.getLength()
#        p @getCardController(_(@gameState.stock).last()).view
    #$(@element).on

App.setupGame = ->
  $ ->
    gameController = new App.GameController
    gameController.initialGameState()
