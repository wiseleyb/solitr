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
    
  commandsForInterTableauPilePlay: ->
    console.log "commandsForInterTableauPiles"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      for j in [0..@zeroIndexNumberOfTableauPiles()]
        console.log "checking #{i},#{j}"
        unless i == j || _.isEmpty(@faceUpTableauPiles[j]) || _.isEmpty(@faceUpTableauPiles[i])
          if @tableauPileAccepts(i,@faceUpTableauPiles[j]) == true
            console.log "moving #{i},#{j}"
            @cmds.push {
              method: 'commandsForInterTableauPiles', 
              command: new App.Models.Command
                action: 'move'
                src: ["faceUpTableauPiles",j]
                dest: ["faceUpTableauPiles",i]
                numberOfCards: @faceUpTableauPiles[j].length
                guiAction: "drag"
                initiator: "user"
              }
    
  commandsForPlayingTableauKingsOnBlanks: ->
    console.log "commandsForPlayingTableauKingsOnBlanks"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      if _.isEmpty(@faceDownTableauPiles[i]) == false && _.isEmpty(@faceUpTableauPiles[i]) == false && _.first(@faceUpTableauPiles[i]).isKing() == true
        console.log "King on stack #{i}"
        for j in [0..@zeroIndexNumberOfTableauPiles()]
          if _.isEmpty(@faceDownTableauPiles[j]) && _.isEmpty(@faceUpTableauPiles[j])
            console.log "Blank found on stack #{j}"
            if @tableauPileAccepts(j,@faceUpTableauPiles[i])
              console.log "moving #{i},#{j}"
              @cmds.push {
                method: 'commandsForPlayingTableauKingsOnBlanks', 
                command: new App.Models.Command
                  action: 'move'
                  src: ["faceUpTableauPiles",i]
                  dest: ["faceUpTableauPiles",j]
                  numberOfCards: @faceUpTableauPiles[i].length
                  guiAction: "drag"
                  initiator: "user"
                }
              
  commandsForMovingTableauCardsToFoundations: ->
    console.log "commandsForMovingTableauCardsToFoundations"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
          console.log "#{i}, #{j}"
          if @foundationAccepts(j,[_.last(@faceUpTableauPiles[i])])
            console.log "moving to foundation #{i},#{j}"
            @cmds.push {
              method: 'commandsForMovingTableauCardsToFoundations', 
              command: new App.Models.Command
                action: 'move'
                src: ["faceUpTableauPiles",i]
                dest: ["foundations",j]
                numberOfCards: 1
                guiAction: "drag"
                initiator: "user"
              }
    
  commandsForPlayingWasteOnTableauPiles: ->
    unless _.isEmpty(@waste)
      console.log "commandsForPlayingWasteOnTableauPiles"
      unless _.isEmpty(@waste)
        for i in [0...@zeroIndexNumberOfTableauPiles()]
          console.log "checking #{i},waste"
          unless _.isEmpty(@faceUpTableauPiles[i])
            if @tableauPileAccepts(i,[_.last(@waste)]) == true
              console.log "moving waste,#{i}"
              @cmds.push {
                method: 'commandsForPlayingWasteOnTableauPiles', 
                command: new App.Models.Command
                  action: 'move'
                  src: ["waste"]
                  dest: ["faceUpTableauPiles",i]
                  numberOfCards: 1
                  guiAction: "drag"
                  initiator: "user"
                }
    
  commandsForPlayingWasteOnFoundations: ->
    unless _.isEmpty(@waste)
      console.log "Check if we can play waste on foundations"
      unless _.isEmpty(@waste)
        for j in [0..3]
          console.log "#{j}"
          if @foundationAccepts(j,[_.last(@waste)])
            console.log "moving waste to foundation #{j}"
            @cmds.push {
              method: 'commandsForPlayingWasteOnFoundations', 
              command: new App.Models.Command
                action: 'move'
                src: ["waste"]
                dest: ["foundations",j]
                numberOfCards: 1
                guiAction: "drag"
                initiator: "user"
              }
    
  commandsForPlayingKingsOnWasteOnTableauPiles: ->
    unless _.isEmpty(@waste)
      console.log "commandsForPlayingKingsOnWasteOnTableauPiles"
      if _.last(@waste).isKing() == true
        for i in [0...@zeroIndexNumberOfTableauPiles()]
          if _.isEmpty(@faceDownTableauPiles[i]) == true && _.isEmpty(@faceUpTableauPiles[i]) == true
            console.log "Blank found on stack #{i}"
            if @tableauPileAccepts(i,[_.last(@waste)])
              @cmds.push {
                method: 'commandsForPlayingKingsOnWasteOnTableauPiles', 
                command: new App.Models.Command
                  action: 'move'
                  src: ["waste"]
                  dest: ["faceUpTableauPiles",i]
                  numberOfCards: 1
                  guiAction: "drag"
                  initiator: "user"
                }
    
  commandsForRedealing: ->
    if _.isEmpty(@stock) # && _.isEmpty(@cmds)
      console.log "commandsForRedealing"
      @cmds.push {
        method: 'commandsForRedealing', 
        command: new App.Models.Command
          action: 'redeal'
          initiator: "user"
        }
    
  commandsForTurningStock: ->
    if !_.isEmpty(@stock) # && _.isEmpty(@cmds)
      console.log "commandsForTurningStock"
      @cmds.push {
        method: 'commandsForTurningStock', 
        command: new App.Models.Command
          action: 'turnStock'
          cardsTurned: 3
          initiator: "user"
        }
        
  nextHintCommand: ->
    console.log "Starting nextHintCommand run"
    @cmds = []
    methods = ['commandsForInterTableauPilePlay',
      'commandsForPlayingTableauKingsOnBlanks',
      'commandsForMovingTableauCardsToFoundations',
      'commandsForMovingTableauCardsToFoundations',
      'commandsForPlayingWasteOnTableauPiles',
      'commandsForPlayingWasteOnFoundations',
      'commandsForPlayingKingsOnWasteOnTableauPiles',
      'commandsForRedealing',
      'commandsForTurningStock']
    for method in methods
      eval("this.#{method}()")
      
    console.log _.groupBy(@cmds, 'method')

    return _.first(@cmds).command unless _.isEmpty(@cmds)
    null   # no move found
