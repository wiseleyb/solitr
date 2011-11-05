#ACCEPT_OVERRIDE = '*'
ACCEPT_OVERRIDE = null

assert = (exp) ->
  throw 'Runtime error' unless exp

p = (exp) ->
  console.log(exp)

set_position = (element_or_selector, left, top) ->
  $(element_or_selector).css
    left: "#{left}px"
    top: "#{top}px"

Array.prototype.last = ->
  this[this.length - 1]

# This can't be right?
remove_from_array = (array, items...) ->
  for item in items
    while item in array
      array.splice(_.indexOf(array, item), 1)

ACE = 0
KING = 12

FIRST_ROW = 20
SECOND_ROW = 250
FIRST_COLUMN = 20
CARD_WIDTH = 120
CARD_HEIGHT = 200
VERTICAL_FANNING_OFFSET = 20
HORIZONTAL_FANNING_OFFSET = 20
COLUMN_OFFSET = CARD_WIDTH + 20

class Card
  @next_id = 0

  constructor: (@rank, @suit, @upturned) ->
    assert @rank? and @suit? and ACE <= rank <= KING and 0 <= suit <= 3 and @upturned?
    @id = "card_#{Card.next_id++}"
    @element = $("<div class=\"card card_#{@rank}_#{@suit}\" id=\"#{@id}\"></div>")
    @update_element()

  update_element: ->
    if @upturned
      @element.html("<div class=\"face\"><!-- #{@id} -->#{'A23456789TJQK'[@rank] + '♣♠♥♦'[@suit]}</div>")
    else
      @element.html("<div class=\"back\"><!-- #{@id} --></div>")

  render_at: (left, top, upturned, z_index = '') ->
    if @upturned != upturned
      @upturned = upturned
      @update_element()
    set_position(@element, left, top)
    @element.css
      'z-index': z_index


class GameState
  constructor: (@canvas_div, @deck) ->

  clone: ->
    copy = new GameState(@canvas_div, @deck)
    for array in ['stock', 'waste']
      copy[array] = this[array].slice(0)
    for array in ['foundations', 'downturned_tableaux', 'upturned_tableaux']
      copy[array] = (subarray.slice(0) for subarray in this[array])
    copy

  deal: ->
    @stock = _.shuffle(@deck)
    @waste = []
    @foundations = [[], [], [], []]
    @downturned_tableaux = [[], [], [], [], [], [], []]
    @upturned_tableaux = [[], [], [], [], [], [], []]
    for i in [0...7]
      for j in [i+1...7]
        @downturned_tableaux[j].push(@stock.pop())
      @upturned_tableaux[i].push(@stock.pop())
    @foundation_blank_html = '<div class="card"><div class="blank"></div></div>'

  get_card: (element) ->
    for c in @deck
      return c if c.element.attr('id') == element.attr('id')

  # Player Actions
  turn: ->
    undo_stack.push(@clone())
    for i in [0...1]
      if @stock.length
        @waste.push(@stock.pop())
    @render()

  redeal: ->
    undo_stack.push(@clone())
    while @waste.length
      @stock.push @waste.pop()
    @render()

  drop_card: (card, target_type, index) ->
    # Drop any legal card on the given foundation or tableau.
    undo_stack.push(@clone())
    assert target_type in ['foundation', 'tableau']
    if card == @waste.last()
      cards = [@waste.pop()]
    else if card in (f.last() for f in @foundations)
      for f in @foundations
        if f.last() == card
          cards = [f.pop()]
    else
      assert card in _.flatten(@upturned_tableaux)
      for t in @upturned_tableaux
        if card in t
          cards = []
          while card in t
            cards.unshift(t.pop()) # ugh
    if target_type == 'foundation'
      assert cards.length == 1
    (if target_type == 'foundation' then @foundations else @upturned_tableaux)[index].push(cards...)
    # Upturn next card if necessary
    for t, index in @upturned_tableaux
      if not t.length and @downturned_tableaux[index].length
        t.push(@downturned_tableaux[index].pop())

  render: ->
    z_index = 1
    # Tableaux
    for i in [0...@downturned_tableaux.length]
      left = FIRST_COLUMN + COLUMN_OFFSET * i
      top = SECOND_ROW
      set_position("#tableau_#{i}_base", left, top)
      for c, index in @downturned_tableaux[i]
        c.render_at(left, top, false, z_index++)
        top += VERTICAL_FANNING_OFFSET
      for c, index in @upturned_tableaux[i]
        c.render_at(left, top, true, z_index++)
        top += VERTICAL_FANNING_OFFSET
      if @upturned_tableaux[i].length
        top -= VERTICAL_FANNING_OFFSET # place dropzone over last card
      set_position("#tableau_#{i}_dropzone", left, top)
    # Stock
    if not @stock.length
      if @waste.length then $('#redeal_image').show() else $('#redeal_image').hide()
      if not @waste.length then $('#exhausted_image').show() else $('#exhausted_image').hide()
    left = FIRST_COLUMN
    top = FIRST_ROW
    set_position('#stock_base', left, top)
    for c in @stock
      c.render_at(left, top, false, z_index++)
    # Waste
    left = FIRST_COLUMN + COLUMN_OFFSET
    top = FIRST_ROW
    set_position('#waste_base', left, top)
    for c, index in @waste
      c.render_at(left, top, true, z_index++)
      if index >= @waste.length - 3
        left += HORIZONTAL_FANNING_OFFSET
    # Foundations
    left = FIRST_COLUMN + 3 * COLUMN_OFFSET
    top = FIRST_ROW
    for foundation, index in @foundations
      set_position("#foundation_#{index}_base", left, top)
      set_position("#foundation_#{index}_dropzone", left, top)
      for c in foundation
        c.render_at(left, top, true, z_index++)
      left += COLUMN_OFFSET

    # Register events
    @canvas_div.off('.solitaire', '**')
    # Set playable cards
    $('.playable').removeClass('playable')
    playable_cards = []
    for stack in [@waste].concat(@foundations, @upturned_tableaux)
      if stack.length
        c = stack[stack.length-1]
        c.element.addClass('playable')
        playable_cards.push(c)
    if @stock.length
      @canvas_div.on 'click.solitaire', "##{@stock[@stock.length-1].id}", =>
        @turn()
    else if @waste.length
      @canvas_div.on 'click.solitaire', "#redeal_image", =>
        @redeal()
    # Drag handlers
    make_draggable = (element, dropzone_to_disable) =>
      # Make the element draggable. Also, disable the dropzone specified when
      # the dragging starts.
      element.draggable
        # Should we define the face/back as a handle?
        #cancel: "##{card.element.attr('id')} .card" # nested cards are not draggable
        revert: 'invalid'
        revertDuration: 200
        stack: '.card'
        start: =>
          if dropzone_to_disable
            $(dropzone_to_disable).droppable('destroy')
        stop: =>
          setTimeout((=> @render()), 0)
    for f, index in @foundations
      if f.length
        e = f[f.length-1].element
        make_draggable(e, "#foundation_#{index}_dropzone")
    if @waste.length
      e = @waste[@waste.length-1].element
      make_draggable(e, null)
    for t, tableau_index in @upturned_tableaux
      for c, card_index in t
        make_draggable(c.element, "#tableau_#{index}_dropzone")
    # Dropzones
    make_droppable = (target_type, index, accept) =>
      dropzone = $("##{target_type}_#{index}_dropzone")
      dropzone.droppable
        tolerance: 'touch'
        accept: ACCEPT_OVERRIDE || accept
        drop: (event, ui) =>
          card = @get_card(ui.draggable)
          @drop_card(card, target_type, index)
          setTimeout((=> @render()), 0)
    for f, index in @foundations
      if f.length
        c = f[f.length-1]
        continue if c.rank == KING
        accept = ".playable.card_#{c.rank+1}_#{c.suit}"
      else
        accept = ".playable.card_0_0, .playable.card_0_1, .playable.card_0_2, .playable.card_0_3"
      make_droppable('foundation', index, accept)
    for t, index in @upturned_tableaux
      if t.length
        c = t.last()
        continue if c.rank == ACE
        if c.suit in [0, 1]
          accept = ".card_#{c.rank-1}_2, .card_#{c.rank-1}_3"
        else
          accept = ".card_#{c.rank-1}_0, .card_#{c.rank-1}_1"
      else
        accept = ".card_#{KING}_0, .card_#{KING}_1, .card_#{KING}_2, .card_#{KING}_3"
      make_droppable('tableau', index, accept)

#  class UndoStack
#    constructor: ->
#      @stack = []

#    push_state(state)

undo_stack = []

# Throwing this into window can't be right?
window.solitaire_main = (canvas_div) ->
  deck = _.flatten(new Card(r, s, false) for r in [ACE..KING] for s in [0..3])
  for c in deck
    canvas_div.append(c.element)
  window.game_state = new GameState(canvas_div, deck)
  window.game_state.deal()
  $('#undo_button').on 'click', =>
    if undo_stack.length
      window.game_state = undo_stack.pop()
      window.game_state.render()
  window.game_state.render()
