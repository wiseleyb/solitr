#= require_self
#= require models

App.CardController = Ember.Object.extend
  model: null

  element: null

  # Eventually this should just memorize the parameters and let the visual
  # updating be handled by animation code.
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

App.TableauController = Ember.Object.extend
  position: null

undealtCardsPosition = [0, 0]
firstColumn = 20
columnOffset = 100
firstRow = 20
secondRow = 250
stockPosition = [firstColumn, firstRow]
wastePosition = [firstColumn + columnOffset, firstRow]
foundationPositions = ([firstColumn + (3 + i) * columnOffset, firstRow] for i in [0...3])
tableauPositions = ([firstColumn + i * columnOffset, secondRow] for i in [0...7])
fanningOffset = 20

App.GameController = Ember.Object.extend
  gameState: null

  init: ->
    # map IDs to views
    @cardControllers = {}

  getCardController: (card) ->
    @cardControllers[card.id]

  initialGameState: ->
    @undealtCards = _(App.createDeck()).shuffle()
    @gameState = App.Models.GameState.create
      tableaux: (App.Models.Tableau.create() for i in [0...7])
      stock: App.Models.Stock.create()
      waste: App.Models.Waste.create()
      foundations: (App.Models.Foundation.create() for i in [0...4])
    # Initialize card controllers
    for card in @undealtCards
      @cardControllers[card.id] = cardController = App.CardController.create
        model: card
      cardController.appendTo(App.rootElement)
    @deal()
    # Wait for DOM to be updated
    setTimeout (=>
      @animateAfterCommand('deal')
      for id, cardController of @cardControllers
        cardController.show()
      #@dealToTableau(gameState.tableaux[0])
    ), 0

  deal: ->
    for tableau, index in @gameState.tableaux
      for i in [0...index]
        tableau.downturnedCards.pushCard(@undealtCards.pop())
      tableau.upturnedCards.pushCard(@undealtCards.pop())
    until @undealtCards.length == 0
      @gameState.stock.pushCard(@undealtCards.pop())

  initializeCardController: (card) ->

  processCommand: (cmd) ->
    @gameState.executeCommand(cmd)
    @animateAfterCommand(cmd)

  animateAfterCommand: (cmd) ->
    #assert cmd.direction == 'do'
#      switch cmd.action
#        when 'move'
#          dest = cmd.dest
#          affectedCardControllers = _(dest.slice(-cmd.numberOfCards)).map (card) =>
#            @getCardController(card)
#          if cmd.
    zIndex = 0
    for card in @gameState.stock.cards
      @getCardController(card).setPosition stockPosition..., zIndex++, false
    for card in @gameState.waste.cards
      @getCardController(card).setPosition wastePosition..., zIndex++, true
    for foundation, index in @gameState.foundations
      for card in foundation.cards
        @getCardController(card).setPosition foundationPositions[index]..., zIndex++, true
    for tableau, index in @gameState.tableaux
      [left, top] = tableauPositions[index]
      offset = 0
      for card in tableau.downturnedCards.cards
        @getCardController(card).setPosition left, top + offset, zIndex++, false
        offset += fanningOffset
      for card in tableau.upturnedCards.cards
        @getCardController(card).setPosition left, top + offset, zIndex++, true
        offset += fanningOffset

#    dealToTableau: (tableau) ->
#      card = @undealtCards.popObject()
#      tableau.downturnedCards.pushCard(card)
#      #@getCardView(card)

App.createDeck = ->
  _(App.Models.Card.create(rank: rank, suit: suit) \
    for rank in App.Models.ranks \
    for suit in App.Models.suits).flatten()

App.ApplicationView = Ember.View.extend
  templateName: 'templates/application'

App.setupGame = ->
  $ ->
    gameController = App.GameController.create()
    gameController.initialGameState()
