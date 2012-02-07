#= require_self
#= require models

# zIndex:
# 0-999: static base elements
# 1000-1999: resting cards
# 2000-2999: animated cards
# 3000-3999: dragging cards

class App.CardController
  constructor: (@model) ->
    @element = null

  @cardWidth: 79
  @cardHeight: 123
  @setToCardSize: (element) ->
    $(element).width(App.CardController.cardWidth).height(App.CardController.cardHeight)

  setRestingState: (pos, zIndex, upturned) ->
    @restingState =
      position: _.clone(pos)
      zIndex: zIndex
      upturned: upturned

  jumpToRestingPosition: ->
    currentState = _(@restingState).clone()
    if parseInt($(@element).css('z-index')) < 1000
      $(@element).css(zIndex: currentState.zIndex)
    $(@element).queue (next) =>
      $(@element).css(zIndex: currentState.zIndex).css(currentState.position)
      next()

  animateToRestingPosition: (options, liftoff=true) ->
    currentState = _(@restingState).clone()
    $(@element).queue (next) =>
      $(@element).css zIndex: currentState.zIndex + if liftoff then 1000 else 0
      next()
    $(@element).animate(currentState.position, options)
    $(@element).queue (next) =>
      $(@element).css zIndex: currentState.zIndex
      next()

  jumpToRestingFace: ->
    currentState = _(@restingState).clone()
    $(@element).queue (next) =>
      $(@element).css backgroundPosition: @getBackgroundPosition(currentState.upturned)
      next()

  # This method flips the card. Only call it if the face state changed
  animateToRestingFace: (options) ->
    $(@element).animate {scale: 1.08},
      duration: options.duration / 9
      easing: 'linear'
    $(@element).animate {scaleX: 0},
      duration: options.duration * 3/9
      easing: 'linear'
    @jumpToRestingFace() # queue new background image
    $(@element).animate {scaleX: 1},
      duration: options.duration * 4/9
      easing: 'linear'
    $(@element).animate {scale: 1},
      duration: options.duration / 9
      easing: 'linear'

  show: -> $(@element).show()
  hide: -> $(@element).hide()

  getBackgroundPosition: (upturned) ->
    [width, height] = [App.CardController.cardWidth, App.CardController.cardHeight]
    if upturned
      left = @model.rank.value * width
      top = _(['clubs', 'diamonds', 'hearts', 'spades']).indexOf(@model.suit.string()) * height
    else
      [left, top] = [2 * width, 4 * height]
    "-#{left}px -#{top}px"

  appendTo: (rootElement) ->
    @element = document.createElement('div')
    @element.className = 'card'
    @element.id = @model.id
    #$(@element).css '-webkit-transform': "rotate(#{Math.random() * 2 - 1}deg)"
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
    @positions =
      undealtCards: {left: 0, top: 0}
      stock: {left: firstColumn, top: firstRow}
      waste: {left: firstColumn + columnOffset, top: firstRow}
      wasteFanningOffset: 20
      foundations: ({left: firstColumn + (3 + i) * columnOffset, top: firstRow} for i in [0...@gameState.numberOfFoundations])
      tableaux: ({left: firstColumn + i * columnOffset, top: secondRow} for i in [0...@gameState.numberOfTableaux])
      tableauFanningOffset: 20

      undoButton: {left: firstColumn + columnOffset * @gameState.numberOfTableaux, top: firstRow}
    @sizes =
      card: {width: App.CardController.cardWidth, height: App.CardController.cardHeight}
      button: {width: App.CardController.cardWidth, height: App.CardController.cardHeight / 3}
    @speeds =
      snap:
        duration: 50
        easing: 'linear'
      snapBack:
        duration: 300
        easing: 'easeOutCubic'
      playToFoundation:
        duration: 450
        easing: 'swing'
      undoMove:
        duration: 300
        easing: 'swing'
      turn:
        duration: 200
        easing: 'swing'
      shift:
        duration: 200
        easing: 'linear'
      flip:
        duration: 150
        # Easing determined by method

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

  getCardControllers: (cardsOrIds) ->
    @getCardController(c) for c in cardsOrIds

  getCardController: (cardOrId) ->
    @cardControllers[if cardOrId instanceof App.Models.Card then cardOrId.id else cardOrId]

  newGame: ->
    @gameState.deal()
    # Initialize card controllers
    for card in @gameState.deck
      @cardControllers[card.id] = new App.CardController(card)
      @cardControllers[card.id].appendTo(@rootElement)
    @animateAfterCommand('deal')
    @registerEventHandlers()
    cardController.show() for id, cardController of @cardControllers

  processUserCommand: (cmd) ->
    @processCommand(cmd)
    while autoCmd = @gameState.nextAutoCommand()
      # Note to self: every animation should tell the world how long the next
      # autoCmd should be delayed.
      @processCommand(autoCmd)
    # Should unblock all events only when last autoCmd processed
    @registerEventHandlers()

  processCommand: (cmd) ->
    @gameState.assertStructure()
    @gameState.executeCommand(cmd)
    @animateAfterCommand(cmd)

  undo: =>
    return unless commands = @gameState.undoStack.pop()
    while cmd = commands.pop()
      @processCommand(cmd)
    @registerEventHandlers()

  animateAfterCommand: (cmd) ->
    @gameState.assertStructure()
    zIndex = 10
    for card in @gameState.stock
      @getCardController(card.id).setRestingState @positions.stock, zIndex++, false
    zIndex = 10
    for card, index in @gameState.waste
      pos = _.clone(@positions.waste)
      pos.left += Math.max(index + Math.min(@gameState.waste.length, @gameState.cardsToTurn) - @gameState.waste.length, 0) * @positions.wasteFanningOffset
      @getCardController(card.id).setRestingState pos, zIndex++, true
    for foundation, index in @gameState.foundations
      zIndex = 10
      for card in foundation
        @getCardController(card.id).setRestingState @positions.foundations[index], zIndex++, true
    for i in [0...@gameState.downturnedTableaux.length]
      zIndex = 10
      pos = _.clone(@positions.tableaux[i])
      for card in @gameState.downturnedTableaux[i]
        @getCardController(card.id).setRestingState pos, zIndex++, false
        pos.top += @positions.tableauFanningOffset
      for card in @gameState.upturnedTableaux[i]
        @getCardController(card.id).setRestingState pos, zIndex++, true
        pos.top += @positions.tableauFanningOffset
    if cmd?
      shiftingCards = []
      switch cmd.action
        when 'move'
          speed = if cmd.direction == 'undo'
            @speeds.snapBack
          else if cmd.guiAction == 'drag'
            @speeds.snap
          else
            @speeds.playToFoundation
          animatedCards = @gameState.getCollection(if cmd.direction == 'do' then cmd.dest else cmd.src) \
            .slice(-cmd.numberOfCards)
          for controller in @getCardControllers(animatedCards)
            controller.animateToRestingPosition(speed)
          shiftingCards = (c for c in @gameState.waste.slice(-@gameState.cardsToTurn) \
                           when c not in animatedCards)
        when 'upturn'
          if cmd.direction == 'do'
            assert @gameState.upturnedTableaux[cmd.tableauIndex].length == 1
            card = @gameState.upturnedTableaux[cmd.tableauIndex][0]
          else
            card = _(@gameState.downturnedTableaux[cmd.tableauIndex]).last()
          @getCardController(card).animateToRestingFace(@speeds.flip)
        when 'turn'
          if cmd.direction == 'do'
            animatedCards = @gameState.waste.slice(-@gameState.cardsToTurn)
            for controller in @getCardControllers(animatedCards)
              controller.animateToRestingPosition(@speeds.turn)
            #shiftingCards = @gameState.waste.slice(-@gameState.cardsToTurn*2+1, -@gameState.cardsToTurn)
            for card in @gameState.waste.slice(-@gameState.cardsToTurn*2+1, -@gameState.cardsToTurn)
              $(@getCardController(card).element).delay(@speeds.turn.duration)
          else
            animatedCards = @gameState.stock.slice(-cmd.cardsTurned)
            for controller in @getCardControllers(animatedCards)
              controller.jumpToRestingFace()
              controller.animateToRestingPosition(@speeds.turn)
        when 'redeal'
          0
      for controller in @getCardControllers(shiftingCards)
        controller.animateToRestingPosition(@speeds.shift, false)
    for controller in _(@cardControllers).values()
      controller.jumpToRestingPosition()
      controller.jumpToRestingFace()
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
        do (locator) =>
          $(@rootElement).on 'dblclick', "##{topMostCard.id}", =>
             @playToAnyFoundation(locator)
    # Everywhere: Drag to move
    $(@rootElement).rawdraggable
      distance: 10
      mouseCapture: (e) =>
        @dragState = {}
        element = document.elementFromPoint(e.clientX, e.clientY)
        isRestingCard = $(element).hasClass('card') and element.id and not $(element).is(':animated')
        # Controller of the card we started dragging
        @dragState.startController = isRestingCard and @getCardController(element.id)
        isRestingCard
      mouseStart: (e) =>
        @dragState.startPagePosition = left: e.pageX, top: e.pageY
        @dragState.cards = @gameState.movableCards(@dragState.startController.model)
        @dragState.controllers = @getCardControllers(@dragState.cards ? [])
        if @dragState.cards
          @dragState.elements = (c.element for c in @dragState.controllers)
        else
          # We cannot drag this card, so drag only its ghost
          clone = $(@dragState.startController.element).clone()
          clone.removeAttr('id', null).css(opacity: '0.5').appendTo(@rootElement)
          @dragState.elements = clone
        @dragState.originalElementPositions = ($(el).position() for el in @dragState.elements)
        for el in @dragState.elements
          $(el).css zIndex: parseInt($(el).css('zIndex') ? '0') + 2000
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
            }, _({}).extend(@speeds.snapBack, complete: -> $(this).remove())
        else
          # Find drop zone with maximum overlap
          mapEl = (c) => (c($(e)) for e in @dragState.elements)
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
              controller.animateToRestingPosition(@speeds.snapBack)

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
    # Seriously IE?!
    if ($.browser.msie)
      $('body').find(':not(input)').attr('unselectable', 'on')

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
          guiAction: 'click'
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
      guiAction: 'drag'

  dump: =>
    "App.gameController.load('#{JSON.stringify(@gameState.dumpHash())}');"

  load: (s) =>
    @gameState.loadHash(JSON.parse(s))
    @animateAfterCommand(null)

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
    App.gameController = new App.GameController
