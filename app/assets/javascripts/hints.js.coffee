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
    $('<div id="score" class="score">Score: 0</div>').css({left: @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 180}) \
      .appendTo(@baseContainer)
      
  registerEventHandlers: ->
    super
    $(@rootElement).on 'click', '.hintButton', @hint
    # $(@rootElement).on 'click', '.runButton',  @run

  hint: =>
    if nextHintCmd = @model.nextHintCommand()
      for cmd in nextHintCmd
        @processUserCommand(cmd)
    else
      alert('No more hints')

class App.Models.KlondikeTurnThreeHints extends App.Models.KlondikeTurnThree
  cardsToTurn: 3
  score: 0
  
  zeroIndexNumberOfTableauPiles: ->
    @numberOfTableauPiles 
    
  commandsForInterTableauPilePlay: ->
    console.log "commandsForInterTableauPiles"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      for j in [0..@zeroIndexNumberOfTableauPiles()-1]
        console.log "checking #{i},#{j}"
        unless i == j || _.isEmpty(@faceUpTableauPiles[j]) || _.isEmpty(@faceUpTableauPiles[i])
          if @tableauPileAccepts(i,@faceUpTableauPiles[j]) == true
            console.log "moving #{i},#{j}"
            @cmds.push {
              method: 'commandsForInterTableauPiles', 
              commands: [
                new App.Models.Command
                  action: 'move'
                  src: ["faceUpTableauPiles",j]
                  dest: ["faceUpTableauPiles",i]
                  numberOfCards: @faceUpTableauPiles[j].length
                  guiAction: "drag"
                  initiator: "user"
                ]
              }
    
  commandsForPlayingTableauKingsOnBlanks: ->
    console.log "commandsForPlayingTableauKingsOnBlanks"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      if _.isEmpty(@faceDownTableauPiles[i]) == false && _.isEmpty(@faceUpTableauPiles[i]) == false && _.first(@faceUpTableauPiles[i]).isKing() == true
        console.log "King on stack #{i}"
        for j in [0..@zeroIndexNumberOfTableauPiles()-1]
          console.log "checking #{i},#{j}"
          if _.isEmpty(@faceDownTableauPiles[j]) && _.isEmpty(@faceUpTableauPiles[j])
            console.log "Blank found on stack #{j}"
            if @tableauPileAccepts(j,@faceUpTableauPiles[i])
              console.log "moving #{i},#{j}"
              @cmds.push {
                method: 'commandsForPlayingTableauKingsOnBlanks', 
                commands: [
                  new App.Models.Command
                    action: 'move'
                    src: ["faceUpTableauPiles",i]
                    dest: ["faceUpTableauPiles",j]
                    numberOfCards: @faceUpTableauPiles[i].length
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }
              
  commandsForMovingTableauCardsToFoundations: ->
    console.log "commandsForMovingTableauCardsToFoundations"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      console.log "#{i}"
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
          console.log "#{i}, #{j}"
          if @foundationAccepts(j,[_.last(@faceUpTableauPiles[i])])
            console.log "moving to foundation #{i},#{j}"
            @cmds.push {
              method: 'commandsForMovingTableauCardsToFoundations', 
              commands: [
                new App.Models.Command
                  action: 'move'
                  src: ["faceUpTableauPiles",i]
                  dest: ["foundations",j]
                  numberOfCards: 1
                  guiAction: "drag"
                  initiator: "user"
                ]
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
                commands: [
                  new App.Models.Command
                    action: 'move'
                    src: ["waste"]
                    dest: ["faceUpTableauPiles",i]
                    numberOfCards: 1
                    guiAction: "drag"
                    initiator: "user"
                  ]
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
              commands: [
                new App.Models.Command
                  action: 'move'
                  src: ["waste"]
                  dest: ["foundations",j]
                  numberOfCards: 1
                  guiAction: "drag"
                  initiator: "user"
                ]
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
                commands: [
                  new App.Models.Command
                    action: 'move'
                    src: ["waste"]
                    dest: ["faceUpTableauPiles",i]
                    numberOfCards: 1
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }
  
  commandsForPlayingFoundationToTableauPiles: ->
    console.log "commandsForPlayingFoundationToTableauPiles"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      console.log "#{i}"
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
          console.log "#{i}, #{j}"
          unless _.isEmpty(@foundations[j])
            if @tableauPileAccepts(i,[_.last(@foundations[j])])
              console.log "moving foundation #{j} to tableau #{i}"
              @cmds.push {
                method: 'commandsForPlayingFoundationToTableauPiles', 
                commands: [
                  new App.Models.Command
                    action: 'move'
                    dest: ["faceUpTableauPiles",i]
                    src: ["foundations",j]
                    numberOfCards: 1
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }

  commandsForRedealing: ->
    if _.isEmpty(@stock) # && _.isEmpty(@cmds)
      console.log "commandsForRedealing"
      @cmds.push {
        method: 'commandsForRedealing', 
        commands: [
          new App.Models.Command
            action: 'redeal'
            initiator: "user"
          ]
        }
    
  commandsForTurningStock: ->
    if !_.isEmpty(@stock) # && _.isEmpty(@cmds)
      console.log "commandsForTurningStock"
      @cmds.push {
        method: 'commandsForTurningStock', 
        commands: [
          new App.Models.Command
            action: 'turnStock'
            cardsTurned: 3
            initiator: "user"
          ]
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
      # 'commandsForPlayingFoundationToTableauPiles',
      'commandsForRedealing',
      'commandsForTurningStock']
    for method in methods
      eval("this.#{method}()")
    
    @cmds = @scoreCmds(@cmds)
    # console.log _.groupBy(@cmds, 'method')
    App.hint_results = @cmds
    return _.first(@cmds).commands unless _.isEmpty(@cmds)
    null   # no move found

  executeCommand: (cmd) ->
    super
    @score += @scoreCmd(cmd)
    $('#score').text("Score: #{@score}")

  scoreCmds: (cmds) ->
    for cmd,i in cmds
      cmds[i]['score'] = 0
      for cmd2 in cmd.commands
        cmds[i]['score'] += @scoreCmd(cmd2)
    return cmds

  # Scoring based on http://en.wikipedia.org/wiki/Klondike_(solitaire)#Scoring
  # Move                    Points
  # Waste to Tableau        5
  # Waste to Foundation     10
  # Tableau to Foundation   10
  # Turn over Tableau card  5
  # Foundation to Tableau   -15
  # Moving cards directly from the Waste stack to a Foundation awards 10 points. However, 
  # if the card is first moved to a Tableau, and then to a Foundation, then an extra 5 points 
  # are received for a total of 15. Thus in order to receive a maximum score, no cards should 
  # be moved directly from the Waste to Foundation.
  # ... time is kind of irrelevant to a computer ..
  # Time can also play a factor in Windows Solitaire, if the Timed game option is selected. For 
  # every 10 seconds of play, 2 points are taken away. Bonus points are calculated with the formula 
  # of 700,000 / (seconds to finish) if the game takes more than 30 seconds. If the game takes less 
  # than 30 seconds, no bonus points are awarded.
  scoreCmd: (cmd) ->
    score = 0
    action = cmd.action if cmd.action?
    src = cmd.src[0] if cmd.src?
    src_index = cmd.src[1] if src && cmd.src.length > 1
    dest = cmd.dest[0] if cmd.dest?
    dest_index = cmd.dest[1] if dest && cmd.dest.length > 1
    if cmd.action == 'move'
      if src == 'waste'
        score += 5 if dest == 'faceUpTableauPiles'
        score += 10 if dest == 'foundations'
      if src == 'faceUpTableauPiles'
        score += 10 if dest == 'foundations'
        score += 5 unless _.isEmpty(@faceDownTableauPiles[src_index])
      if src == "foundations"
        score += -15 if dest == "faceUpTableauPile"
    return score
