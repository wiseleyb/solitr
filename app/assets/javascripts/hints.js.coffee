class App.Controllers.KlondikeTurnThreeHints extends App.Controllers.Klondike
  createModel: -> new App.Models.KlondikeTurnThreeHints
      
  appendBaseElements: () ->
    super
    @positions.hintButton = {left: @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 60}
    # @positions.runButton = {left:  @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 120}
    $('<div class="button gray hintButton">Hint</div>').css(@positions.hintButton) \
      .appendTo(@baseContainer)
    # $('<div class="button gray runButton">Run</div>').css(@positions.runButton) \
    #   .appendTo(@baseContainer)

  registerEventHandlers: ->
    super
    $(@rootElement).on 'click', '.hintButton', @hint
    # $(@rootElement).on 'click', '.runButton',  @run

  hint: =>
    if nextHintCmd = @model.nextHintCommand()
      @processUserCommand(nextHintCmd)
    else
      alert('No more hints')

class App.Models.KlondikeTurnThreeHints extends App.Models.KlondikeTurnThree
  cardsToTurn: 3

  zeroIndexNumberOfTableauPiles: ->
    @numberOfTableauPiles - 1
    
  commandsForInterTableauPiles: ->
    console.log "Check for card plays"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      for j in [0..@zeroIndexNumberOfTableauPiles()]
        console.log "checking #{i},#{j}"
        unless i == j || _.isEmpty(@faceUpTableauPiles[j]) || _.isEmpty(@faceUpTableauPiles[i])
          if @tableauPileAccepts(i,@faceUpTableauPiles[j]) == true
            console.log "moving #{i},#{j}"
            cmd = new App.Models.Command
              action: 'move'
              src: ["faceUpTableauPiles",j]
              dest: ["faceUpTableauPiles",i]
              numberOfCards: @faceUpTableauPiles[j].length
              guiAction: "drag"
              initiator: "user"
            App.next_hint_cmd = cmd
            return cmd
    null
    
  commandsForPlayingTableauKingsOnBlanks: ->
    console.log "Check for kings on stacks that can be moved to blank spots"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      if _.isEmpty(@faceDownTableauPiles[i]) == false && _.isEmpty(@faceUpTableauPiles[i]) == false && _.first(@faceUpTableauPiles[i]).isKing() == true
        console.log "King on stack #{i}"
        for j in [0..@zeroIndexNumberOfTableauPiles()]
          if _.isEmpty(@faceDownTableauPiles[j]) && _.isEmpty(@faceUpTableauPiles[j])
            console.log "Blank found on stack #{j}"
            if @tableauPileAccepts(j,@faceUpTableauPiles[i])
              console.log "moving #{i},#{j}"
              cmd = new App.Models.Command
                action: 'move'
                src: ["faceUpTableauPiles",i]
                dest: ["faceUpTableauPiles",j]
                numberOfCards: @faceUpTableauPiles[i].length
                guiAction: "drag"
                initiator: "user"
              App.next_hint_cmd = cmd
              return cmd
    null
              
  commandsForMovingTableauCardsToFoundations: ->
    console.log "Check for cards to move up to foundations"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
          console.log "#{i}, #{j}"
          if @foundationAccepts(j,[_.last(@faceUpTableauPiles[i])])
            console.log "moving to foundation #{i},#{j}"
            cmd = new App.Models.Command
              action: 'move'
              src: ["faceUpTableauPiles",i]
              dest: ["foundations",j]
              numberOfCards: 1
              guiAction: "drag"
              initiator: "user"
            App.next_hint_cmd = cmd
            return cmd
    null
    
  commandsForPlayingWasteOnTableauPiles: ->
    unless _.isEmpty(@waste)
      console.log "Check if we can play waste on faceUpTableauPiles"
      unless _.isEmpty(@waste)
        for i in [0...@zeroIndexNumberOfTableauPiles()]
          console.log "checking #{i},waste"
          unless _.isEmpty(@faceUpTableauPiles[i])
            if @tableauPileAccepts(i,[_.last(@waste)]) == true
              console.log "moving waste,#{i}"
              cmd = new App.Models.Command
                action: 'move'
                src: ["waste"]
                dest: ["faceUpTableauPiles",i]
                numberOfCards: 1
                guiAction: "drag"
                initiator: "user"
              App.next_hint_cmd = cmd
              return cmd
    null
    
  commandsForPlayingWasteOnFoundations: ->
    unless _.isEmpty(@waste)
      console.log "Check if we can play waste on foundations"
      unless _.isEmpty(@waste)
        for j in [0..3]
          console.log "#{j}"
          if @foundationAccepts(j,[_.last(@waste)])
            console.log "moving waste to foundation #{j}"
            cmd = new App.Models.Command
              action: 'move'
              src: ["waste"]
              dest: ["foundations",j]
              numberOfCards: 1
              guiAction: "drag"
              initiator: "user"
            App.next_hint_cmd = cmd
            return cmd
    null
    
  commandsForPlayingKingsOnWasteOnTableauPiles: ->
    unless _.isEmpty(@waste)
      console.log "Check for kings on waste that can be moved to blank spots"
      if _.last(@waste).isKing() == true
        for i in [0...@zeroIndexNumberOfTableauPiles()]
          if _.isEmpty(@faceDownTableauPiles[i]) == true && _.isEmpty(@faceUpTableauPiles[i]) == true
            console.log "Blank found on stack #{i}"
            if @tableauPileAccepts(i,[_.last(@waste)])
              console.log "moving waste to #{i}"
              cmd = new App.Models.Command
                action: 'move'
                src: ["waste"]
                dest: ["faceUpTableauPiles",i]
                numberOfCards: 1
                guiAction: "drag"
                initiator: "user"
              App.next_hint_cmd = cmd
              return cmd
    null
    
  commandsForRedealing: ->
    unless _.isEmpty(@stock) && _.isEmpty(@waste)
      if _.isEmpty(@stock)
        console.log "Redeal"
        cmd = new App.Models.Command
          action: 'redeal'
          initiator: "user"
        App.next_hint_cmd = cmd
        return cmd
    null
    
  commandsForTurningStock: ->
    unless _.isEmpty(@stock) && _.isEmpty(@waste)
      unless _.isEmpty(@stock)
        console.log "Turn stock"
        cmd = new App.Models.Command
          action: 'turnStock'
          cardsTurned: 3
          initiator: "user"
        App.next_hint_cmd = cmd
        return cmd
    null
        
  nextHintCommand: ->
    console.log "Starting nextHintCommand run"
    
    cmd = @commandsForInterTableauPiles()
    return cmd unless cmd == null
      
    cmd = @commandsForPlayingTableauKingsOnBlanks()
    return cmd unless cmd == null
              
    cmd = @commandsForMovingTableauCardsToFoundations()
    return cmd unless cmd == null

    cmd = @commandsForMovingTableauCardsToFoundations()
    return cmd unless cmd == null

    cmd = @commandsForPlayingWasteOnTableauPiles()
    return cmd unless cmd == null

    cmd = @commandsForPlayingWasteOnFoundations()
    return cmd unless cmd == null

    cmd = @commandsForPlayingKingsOnWasteOnTableauPiles()
    return cmd unless cmd == null

    cmd = @commandsForRedealing()
    return cmd unless cmd == null

    cmd = @commandsForTurningStock()
    return cmd unless cmd == null
    
    null   # no move found
