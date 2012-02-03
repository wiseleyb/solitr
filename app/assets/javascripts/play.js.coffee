#= require_self
#= require models

App.CardController = Ember.Object.extend
  model: null

  upturned: false

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
      $(@element).css backgroundPosition: "-#{@get('model').get('rank') * 79}px -#{_(['clubs', 'diamonds', 'hearts', 'spades']).indexOf(@get('model').get('suit')) * 123}px"
    else
      $(@element).css backgroundPosition: "-#{2 * 79}px -#{4 * 123}px"

  appendTo: (rootElement) ->
    @element = document.createElement('div')
    @element.className = 'card'
    @element.id = @get('model').get('id')
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
    @cardControllers[card.get 'id']

  initialGameState: ->
    @undealtCards = _(App.createDeck()).shuffle()
    @gameState = App.Models.GameState.create
      tableaux: (App.Models.Tableau.create() for i in [0...7])
      stock: App.Models.Stock.create()
      waste: App.Models.Waste.create()
      foundations: (App.Models.Foundation.create() for i in [0...4])
    # Initialize card controllers
    for card in @undealtCards
      @cardControllers[card.get 'id'] = cardController = App.CardController.create
        model: card
      cardController.appendTo(App.rootElement)
    @deal()
    # Wait for DOM to be updated
    setTimeout (=>
      @animateAfterCommand('deal')
      for id, cardController of @cardControllers
        cardController.show()
      #@dealToTableau(gameState.get('tableaux')[0])
    ), 0

  deal: ->
    for tableau, index in @gameState.get('tableaux')
      for i in [0...index]
        tableau.downturnedCards.pushCard(@undealtCards.pop())
      tableau.upturnedCards.pushCard(@undealtCards.pop())
    until @undealtCards.length == 0
      @gameState.get('stock').pushCard(@undealtCards.pop())

  initializeCardController: (card) ->

  processCommand: (cmd) ->
    @gameState.executeCommand(cmd)
    @animateAfterCommand(cmd)

  animateAfterCommand: (cmd) ->
    #assert cmd.direction == 'do'
#      switch cmd.get('action')
#        when 'move'
#          dest = cmd.get('dest')
#          affectedCardControllers = _(dest.slice(-cmd.get('numberOfCards'))).map (card) =>
#            @getCardController(card)
#          if cmd.
    zIndex = 0
    for card in @gameState.get('stock').cards
      @getCardController(card).setPosition stockPosition..., zIndex++, false
    for card in @gameState.get('waste').cards
      @getCardController(card).setPosition wastePosition..., zIndex++, true
    for foundation, index in @gameState.get('foundations')
      for card in foundation.get 'cards'
        @getCardController(card).setPosition foundationPositions[index]..., zIndex++, true
    for tableau, index in @gameState.get('tableaux')
      [left, top] = tableauPositions[index]
      offset = 0
      for card in tableau.get('downturnedCards').get('cards')
        @getCardController(card).setPosition left, top + offset, zIndex++, false
        offset += fanningOffset
      for card in tableau.get('upturnedCards').get('cards')
        @getCardController(card).setPosition left, top + offset, zIndex++, true
        offset += fanningOffset

#    dealToTableau: (tableau) ->
#      card = @undealtCards.popObject()
#      tableau.get('downturnedCards').pushCard(card)
#      #@getCardView(card)

App.createDeck = ->
  _(App.Models.Card.create(rank: rank, suit: suit) \
    for rank in App.Models.Card.ranks \
    for suit in App.Models.Card.suits).flatten()

App.ApplicationView = Ember.View.extend
  templateName: 'templates/application'

App.setupGame = ->
  $ ->
    gameController = App.GameController.create()
    gameController.initialGameState()
