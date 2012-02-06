#= require_self
#= require models

class App.CardController
  constructor: (@model) ->
    @element = null

  @cardWidth: 79
  @cardHeight: 123
  @setToCardSize: (element) ->
    $(element).width(App.CardController.cardWidth).height(App.CardController.cardHeight)

  setPosition: (pos, zIndex, upturned) ->
    @restingState =
      position: _.clone(pos)
      zIndex: zIndex
      upturned: upturned
    $(@element).css(pos).css(zIndex: zIndex)
    @setUpturned(upturned)

  show: -> $(@element).show()
  hide: -> $(@element).hide()

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
    App.CardController.setToCardSize(@element)
    $(rootElement).append($(@element))

class App.GameController
  gameState: null

  constructor: ->
    @gameState = new App.Models.GameState
    @cardControllers = {} # map IDs to views
    @rootElement = $(App.rootElement)[0]
    @calculateGeometry()
    @appendBaseElements()
    @newGame()

  calculateGeometry: () ->
    firstColumn = 20
    columnOffset = App.CardController.cardWidth + 20
    firstRow = 20
    secondRow = 180
    @positions = {
      undealtCards: {left: 0, top: 0}
      stock: {left: firstColumn, top: firstRow}
      waste: {left: firstColumn + columnOffset, top: firstRow}
      wasteFanningOffset: 20
      foundations: ({left: firstColumn + (3 + i) * columnOffset, top: firstRow} for i in [0...@gameState.numberOfFoundations])
      tableaux: ({left: firstColumn + i * columnOffset, top: secondRow} for i in [0...@gameState.numberOfTableaux])
      tableauFanningOffset: 20

      undoButton: {left: firstColumn + columnOffset * @gameState.numberOfTableaux, top: firstRow}
    }
    @sizes = {
      card: {width: App.CardController.cardWidth, height: App.CardController.cardHeight}
      button: {width: App.CardController.cardWidth, height: App.CardController.cardHeight / 3}
    }

  appendBaseElements: () ->
    baseContainer = $('<div class="baseContainer"></div>')
    makeBaseCardElement = (name, id) =>
      $("<div class='#{name} baseCardElement' id='#{id ? name}'></div>") \
        .css(@sizes.card).css(
          backgroundPosition: "-#{3 * @sizes.card.width}px -#{4 * @sizes.card.height}px"
        ).appendTo(baseContainer)

    makeBaseCardElement('exhaustedImage').css(@positions.stock)
    makeBaseCardElement('redealImage').css(@positions.stock)
    $('<div class="button undoButton">Undo</div>').css(@positions.undoButton) \
      .css(@sizes.button).css(lineHeight: "#{@sizes.button.height+1}px").appendTo(baseContainer)

    for i in [0...@gameState.numberOfFoundations]
      makeBaseCardElement('foundationBase', "foundationBase#{i}").css @positions.foundations[i]
    for i in [0...@gameState.numberOfTableaux]
      makeBaseCardElement('tableauBase', "tableauBase#{i}").css @positions.tableaux[i]
    for element in baseContainer.find('base')
      App.CardController.setToCardSize(element)
    $(@rootElement).append(baseContainer)

  getCardController: (id) ->
    @cardControllers[id]

  newGame: ->
    @gameState.deal()
    # Initialize card controllers
    for card in @gameState.deck
      @cardControllers[card.id] = new App.CardController(card)
      @cardControllers[card.id].appendTo(@rootElement)
    @animateAfterCommand('deal')
    cardController.show() for id, cardController of @cardControllers

  processUserCommand: (cmd) ->
    @processCommand(cmd)
    while autoCmd = @gameState.nextAutoCommand()
      @processCommand(autoCmd)

  processCommand: (cmd) ->
    @gameState.assertStructure()
    @gameState.executeCommand(cmd)
    @animateAfterCommand(cmd)

  undo: =>
    return unless commands = @gameState.undoStack.pop()
    while cmd = commands.pop()
      @processCommand(cmd)

  animateAfterCommand: (cmd) ->
    @gameState.assertStructure()
    zIndex = 10
    for card in @gameState.stock
      @getCardController(card.id).setPosition @positions.stock, zIndex++, false
    for card, index in @gameState.waste
      pos = _.clone(@positions.waste)
      pos.left += Math.max(index + Math.min(@gameState.waste.length, @gameState.cardsToTurn) - @gameState.waste.length, 0) * @positions.wasteFanningOffset
      @getCardController(card.id).setPosition pos, zIndex++, true
    for foundation, index in @gameState.foundations
      for card in foundation
        @getCardController(card.id).setPosition @positions.foundations[index], zIndex++, true
    for i in [0...@gameState.downturnedTableaux.length]
      pos = _.clone(@positions.tableaux[i])
      for card in @gameState.downturnedTableaux[i]
        @getCardController(card.id).setPosition pos, zIndex++, false
        pos.top += @positions.tableauFanningOffset
      for card in @gameState.upturnedTableaux[i]
        @getCardController(card.id).setPosition pos, zIndex++, true
        pos.top += @positions.tableauFanningOffset
    @registerEventHandlers()
    @updateWidgets()

  removeEventHandlers: ->
    $(@rootElement).rawdraggable('destroy')
    $(@rootElement).off()

  registerEventHandlers: ->
    @removeEventHandlers()
    # Buttons
    $(@rootElement).on 'click', '.undoButton', @undo
    # Stock: Click to Turn and redeal
    if @gameState.stock.length
      stockCard = _(@gameState.stock).last()
      $(@rootElement).on 'click', "##{stockCard.id}", @turnStock
    else if @gameState.waste.length
      $(@rootElement).on 'click', "#redealImage", @redeal
    # Tableaux: Doubleclick to play to foundation
    for locator in [['waste'], (['upturnedTableaux', i] for i in [0...@gameState.upturnedTableaux.length])...]
      if topMostCard = _(@gameState.getCollection(locator)).last()
        ((locator) => $(@rootElement).on 'dblclick', "##{topMostCard.id}", =>
          @playToAnyFoundation(locator))(locator)
    # Everywhere: Drag to move
    $(@rootElement).rawdraggable
      distance: 10
      mouseCapture: (e) =>
        @dragState = {}
        element = document.elementFromPoint(e.clientX, e.clientY)
        isCard = $(element).hasClass('card') and element.id
        # Controller of the card we started dragging
        @dragState.startController = isCard and @getCardController(element.id)
        isCard
      mouseStart: (e) =>
        @dragState.startPagePosition = left: e.pageX, top: e.pageY
        @dragState.cards = @gameState.movableCards(@dragState.startController.model)
        @dragState.controllers = _(@dragState.cards ? []).map (c) => @getCardController(c.id)
        if @dragState.cards
          @dragState.elements = @dragState.controllers.map (c) => c.element
        else
          # We cannot drag this card, so drag only its ghost
          clone = $(@dragState.startController.element).clone()
          clone.removeAttr('id', null).css(opacity: '0.5').appendTo(@rootElement)
          @dragState.elements = clone
        @dragState.originalElementPositions = _(@dragState.elements).map (el) ->
          $(el).position()
        for el in @dragState.elements
          $(el).css zIndex: $(el).css('zIndex') + 1000
      mouseDrag: (e) =>
        #@_visualizeDropZones(@dragState.cards)
        for el, i in @dragState.elements
          $(el).css
            left: @dragState.originalElementPositions[i].left + (e.pageX - @dragState.startPagePosition.left)
            top: @dragState.originalElementPositions[i].top + (e.pageY - @dragState.startPagePosition.top)
      mouseStop: (e) =>
        if not @dragState.cards
          # Snap back ghost
          for el, i in @dragState.elements
            $(el).animate {
              left: @dragState.originalElementPositions[i].left
              top: @dragState.originalElementPositions[i].top
            }, -> $(this).remove()
        else
          # Find drop zone with maximum overlap
          mapEl = (c) => _(@dragState.elements).map (e) -> c($(e))
          extent =
            minLeft: Math.min (mapEl (e) -> e.offset().left)...
            minTop: Math.min (mapEl (e) -> e.offset().top)...
            maxLeft: Math.max (mapEl (e) -> e.offset().left + e.width())...
            maxTop: Math.max (mapEl (e) -> e.offset().top + e.height())...
          maxOverlapArea = 0
          targetDropZone = null
#            @_drawVisualization
#              left: extent.minLeft
#              top: extent.minTop
#              width: extent.maxLeft - extent.minLeft
#              height: extent.maxTop - extent.minTop
          for dropZone in @getDropZones(@dragState.cards)
            overlap = {}
            overlap.left = Math.max(dropZone.left, extent.minLeft)
            overlap.width = Math.max(Math.min(dropZone.left + dropZone.width, extent.maxLeft) \
                                     - overlap.left, 0)
            overlap.top = Math.max(dropZone.top, extent.minTop)
            overlap.height = Math.max(Math.min(dropZone.top + dropZone.height, extent.maxTop) \
                                      - overlap.top, 0)
            overlap.area = overlap.width * overlap.height
            if overlap.area > maxOverlapArea
              maxOverlapArea = overlap.area
              targetDropZone = dropZone
          if targetDropZone
            @move(@dragState.cards, targetDropZone.locator)
          else
            # Snap back cards
            for controller in @dragState.controllers
              ((controller) =>
                $(controller.element).animate controller.restingState.position, ->
                  $(controller.element).css zIndex: controller.restingState.zIndex
                )(controller)

  getDropZones: (cards) ->
    dropZones = []
    for locator, i in @gameState.locators.foundations
      if @gameState.foundationAccepts(i, cards)
        dropZones.push
          locator: locator
          top: @positions.foundations[i].top
          left: @positions.foundations[i].left
          width: App.CardController.cardWidth
          height: App.CardController.cardHeight
    for locator, i in @gameState.locators.upturnedTableaux
      if @gameState.tableauAccepts(i, cards)
        tableauLength = @gameState.downturnedTableaux[i].length + \
          @gameState.upturnedTableaux[i].length
        tableauLength-- if tableauLength # place on topmost card, not on actual drop point
        dropZones.push
          locator: locator
          top: @positions.tableaux[i].top + tableauLength * @positions.tableauFanningOffset
          left: @positions.tableaux[i].left
          width: App.CardController.cardWidth
          height: App.CardController.cardHeight
    dropZones

  # development aid
  _visualizeDropZones: (cards) ->
    $('.visualization').remove()
    for dropZone in @getDropZones(cards)
      @_drawVisualization dropZone

  _drawVisualization: (rect) -> # top, left, width, height
    $('<div class="visualization"></div>').css(rect).appendTo(@rootElement)

  updateWidgets: ->
    setVisibility = (element, visible) ->
      if visible then $(element).show() else $(element).hide()
    exhausted = @gameState.stock.length == @gameState.waste.length == 0
    setVisibility '.exhaustedImage', exhausted
    setVisibility '.redealImage', not exhausted
#      for foundation, i in @gameState.foundations
#        setVisibility "#foundationBase#{i}", foundation.length == 0

  turnStock: =>
    @processUserCommand(new App.Models.Command(action: 'turn'))

  redeal: =>
    @processUserCommand(new App.Models.Command(action: 'redeal'))

  playToAnyFoundation: (src) =>
    collection = @gameState.getCollection(src)
    card = _(collection).last()
    assert card
    for foundationIndex in [0...@gameState.foundations.length]
      if @gameState.foundationAccepts(foundationIndex, [card])
        @processUserCommand new App.Models.Command
          action: 'move'
          src: src
          dest: ['foundations', foundationIndex]
          numberOfCards: 1
        break

  move: (cards, dest) =>
    @gameState._assertLocator(dest)
    assert cards instanceof Array
    assert cards.length == 1, dest, cards unless dest[0] == 'upturnedTableaux'
    @processUserCommand new App.Models.Command
      action: 'move'
      src: @gameState.getLocator(cards[0])
      dest: dest
      numberOfCards: cards.length

$.widget 'ui.rawdraggable', $.ui.mouse,
  widgetEventPrefix: 'rawdraggable'
  options:
    mouseCapture: (e) -> true # capture everything by default
    mouseStart: (e) ->
    mouseDrag: (e) ->
    mouseStop: (e) ->
  _init: ->
    @_mouseInit()
  _destroy: ->
    @_mouseDestroy()
  _create: ->
    @element.addClass('ui-rawdraggable')
  _destroy: ->
    @element.removeClass('ui-rawdraggable')
  _mouseStart: (e) -> @options.mouseStart(e)
  _mouseDrag: (e) -> @options.mouseDrag(e)
  _mouseStop: (e) -> @options.mouseStop(e)
  _mouseCapture: (e) -> @options.mouseCapture(e)

App.setupGame = ->
  $ ->
    gameController = new App.GameController
