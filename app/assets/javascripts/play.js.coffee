#= require_self
#= require models

class App.CardController
  constructor: (@model) ->
    @element = null

  @cardWidth: 79
  @cardHeight: 123
  @setToCardSize: (element) ->
    $(element).width(App.CardController.cardWidth).height(App.CardController.cardHeight)

  # Eventually this should just save the parameters as a "resting position" and
  # let the visual updating be handled by animation code.
  setPosition: (pos, zIndex, upturned) ->
    $(@element).css(pos).css(zIndex: zIndex)
    App.CardController.setToCardSize(@element)
    @setUpturned(upturned)

  show: ->
    $(@element).show()

  setUpturned: (upturned) ->
    [width, height] = [App.CardController.cardWidth, App.CardController.cardHeight]
    if upturned
      left = @model.rank.value * width
      top = _(['clubs', 'diamonds', 'hearts', 'spades']).indexOf(@model.suit.string()) * height
    else
      [left, top] = [2 * width, 4 * height]
    $(@element).css backgroundPosition: "-#{left}px -#{top}px"

  appendTo: (rootElement) ->
    @element = document.createElement('div')
    @element.className = 'card'
    @element.id = @model.id
    #$(@element).css '-webkit-transform': "rotate(#{Math.random() * 2 - 1}deg)"
    @setUpturned(false)
    $(rootElement).append($(@element))

class App.GameController
  gameState: null

  constructor: ->
    @cardControllers = {} # map IDs to views
    @element = $(App.rootElement)[0]
    @positions = @calculatePositions()
    @appendBaseElements()
    @newGame()

  calculatePositions: () ->
    firstColumn = 20
    columnOffset = App.CardController.cardWidth + 20
    firstRow = 20
    secondRow = 250
    {
      undealtCards: {left: 0, top: 0}
      stock: {left: firstColumn, top: firstRow}
      waste: {left: firstColumn + columnOffset, top: firstRow}
      wasteFanningOffset: 20
      foundations: ({left: firstColumn + (3 + i) * columnOffset, top: firstRow} for i in [0...4])
      tableaux: ({left: firstColumn + i * columnOffset, top: secondRow} for i in [0...7])
      tableauFanningOffset: 20
    }

  appendBaseElements: () ->
    baseContainer = $('<div class="baseContainer"></div>')
    makeBaseCardElement = (name, id) ->
      e = App.CardController.setToCardSize($("<div class='#{name} baseCardElement' id='#{id ? name}'></div>"))
      baseContainer.append(e)
      e
    makeBaseCardElement('exhaustedImage').css(@positions.stock)
    makeBaseCardElement('redealImage').css(@positions.stock)

    for i in [0...@positions.foundations.length]
      makeBaseCardElement('foundationBase', "foundationBase#{i}").css @positions.foundations[i]
    for element in baseContainer.find('div')
      App.CardController.setToCardSize(element)
    $(@element).append(baseContainer)

  getCardController: (card) ->
    @cardControllers[card.id]

  newGame: ->
    @gameState = new App.Models.GameState
    @gameState.deal()
    # Initialize card controllers
    for card in @gameState.deck
      @cardControllers[card.id] = cardController = new App.CardController(card)
      cardController.appendTo(@element)
    @animateAfterCommand('deal')
    cardController.show() for id, cardController of @cardControllers
    @gameState.assertStructure()
    @registerEventHandlers()
    @updateWidgets()

  processUserCommand: (cmd) ->
    @processCommand(cmd)
    while autoCmd = @gameState.nextAutoCommand()
      @processCommand(autoCmd)

  processCommand: (cmd) ->
    @gameState.assertStructure()
    @gameState.executeCommand(cmd)
    @gameState.assertStructure()
    @animateAfterCommand(cmd)
    @registerEventHandlers()
    @updateWidgets()

  animateAfterCommand: (cmd) ->
    zIndex = 10
    for card in @gameState.stock
      @getCardController(card).setPosition @positions.stock, zIndex++, false
    for card, index in @gameState.waste
      pos = _.clone(@positions.waste)
      pos.left += Math.max(index + Math.min(@gameState.waste.length, 3) - @gameState.waste.length, 0) * @positions.wasteFanningOffset
      @getCardController(card).setPosition pos, zIndex++, true
    for foundation, index in @gameState.foundations
      for card in foundation
        @getCardController(card).setPosition @positions.foundations[index], zIndex++, true
    for i in [0...@gameState.downturnedTableaux.length]
      pos = _.clone(@positions.tableaux[i])
      for card in @gameState.downturnedTableaux[i]
        @getCardController(card).setPosition pos, zIndex++, false
        pos.top += @positions.tableauFanningOffset
      for card in @gameState.upturnedTableaux[i]
        @getCardController(card).setPosition pos, zIndex++, true
        pos.top += @positions.tableauFanningOffset

  removeEventHandlers: ->
    $(@element).off()

  registerEventHandlers: ->
    @removeEventHandlers()
    # Turn and redeal
    if @gameState.stock.length
      stockCard = _(@gameState.stock).last()
      $(@element).on 'click', "##{stockCard.id}", @turnStock
    else if @gameState.waste.length
      $(@element).on 'click', "#redealImage", @redeal
    # Play
    for locator in [['waste'], (['upturnedTableaux', i] for i in [0...@gameState.upturnedTableaux.length])...]
      if topMostCard = _(@gameState.getCollection(locator)).last()
        ((locator) => $(@element).on 'dblclick', "##{topMostCard.id}", =>
          @moveToAnyFoundation(locator))(locator)

  updateWidgets: ->
    setVisibility = (element, visible) ->
      if visible then $(element).show() else $(element).hide()
    setVisibility '.exhaustedImage', \
      @gameState.stock.length == @gameState.waste.length == 0
    setVisibility '.redealImage', \
      @gameState.stock.length == 0 and @gameState.waste.length > 0
    for foundation, i in @gameState.foundations
      setVisibility "#foundationBase#{i}", foundation.length == 0

  turnStock: =>
    @processUserCommand(new App.Models.Command(action: 'turn'))

  redeal: =>
    @processUserCommand(new App.Models.Command(action: 'redeal'))

  moveToAnyFoundation: (src) =>
    collection = @gameState.getCollection(src)
    return unless card = _(collection).last()
    for foundationIndex in [0...@gameState.foundations.length]
      if @gameState.foundationAccepts(foundationIndex, card)
        @processUserCommand new App.Models.Command
          action: 'move'
          src: src
          dest: ['foundations', foundationIndex]
          numberOfCards: 1
        break

App.setupGame = ->
  $ ->
    gameController = new App.GameController
