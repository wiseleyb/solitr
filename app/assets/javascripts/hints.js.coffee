
class App.Controllers.KlondikeTurnThreeHints extends App.Controllers.Klondike
  createModel: -> new App.Models.KlondikeTurnThreeHints
      
  appendBaseElements: () ->
    super
    @positions.hintButton = {left: @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 60}
    @positions.runButton = {left:  @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 120}
    $('#hint_button').remove()
    $('#score').remove()
    $('#moves').remove()
    $('#run_button').remove()
    
    $('<div id="hint_button" class="button gray hintButton">Hint</div>').css(@positions.hintButton) \
      .appendTo(@baseContainer)
    $('<div id="run_button" class="button gray runButton">Run</div>').css(@positions.runButton) \
      .appendTo(@baseContainer)
    $('<div id="score" class="score">Score: 0</div>').css({left: @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 180}) \
      .appendTo(@baseContainer)
    $('<div id="moves" class="moves">Moves: 0</div>').css({left: @geometry.firstColumn +  @geometry.columnOffset * @model.numberOfTableauPiles, top:  @geometry.firstRow + 210}) \
      .appendTo(@baseContainer)
    
  registerEventHandlers: ->
    super
    $(@rootElement).on 'click', '.hintButton', @hint
    $(@rootElement).on 'click', '.runButton',  @run

  hint: =>
    if nextHintCmd = @model.nextHintCommand()
      for cmd in nextHintCmd
        @processUserCommand(cmd)
    else
      alert('No more hints')
    
  run: =>
    console.log $('#run_button').html()
    if $('#run_button').html() == 'Run'
      console.log "Button: Run"
      window.timer.poll()
      $('#run_button').text('Pause')
      return
    
    if $('#run_button').html() == "Pause"
      console.log "Button: Pause"
      window.timer.pause()
      $('#run_button').text('Continue')
      return
      
    if $('#run_button').html() == "Continue"
      console.log "Button: Continue"
      window.timer.unpause()
      $('#run_button').text('Pause')
      return

  processUserCommand: (cmd) ->
    window.timer.pause()
    for t in window.timers
      clearTimeout(t)
    if @model.moves > 200
      alert('Game halted - too many moves')
      return
      
    @removeEventHandlers()
    @processCommand(cmd)
    if nextCmd = @model.nextAutoCommand()
      window.timers.push(setTimeout (=> @processUserCommand(nextCmd)), @nextAnimationDelay(cmd))
      window.timer.unpause()
    else if @model.isWon()
      window.timers.push(setTimeout @youWin, @nextAnimationDelay(cmd))
    else
      @registerEventHandlers()
      window.timer.unpause()
                
class App.Models.KlondikeTurnThreeHints extends App.Models.KlondikeTurnThree
  cardsToTurn: 3
  score: 0
  moves: 0
  
  zeroIndexNumberOfTableauPiles: ->
    @numberOfTableauPiles 
  
  cloneCards: (cards) ->
    _.map cards, (card) -> card.deepClone()
    
  commandsForInterTableauPilePlay: ->
    console.log "commandsForInterTableauPiles"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      for j in [0..@zeroIndexNumberOfTableauPiles()-1]
        # console.log "checking #{i},#{j}"
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
                  cards: @cloneCards(@faceUpTableauPiles[j])
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
          # console.log "checking #{i},#{j}"
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
                    cards: @cloneCards(@faceUpTableauPiles[i])
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }
              
  commandsForMovingTableauCardsToFoundations: ->
    console.log "commandsForMovingTableauCardsToFoundations"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
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
                  cards: @cloneCards([_.last(@faceUpTableauPiles[i])])
                  guiAction: "drag"
                  initiator: "user"
                ]
              }
    
  commandsForPlayingWasteOnTableauPiles: ->
    unless _.isEmpty(@waste)
      console.log "commandsForPlayingWasteOnTableauPiles"
      unless _.isEmpty(@waste)
        for i in [0...@zeroIndexNumberOfTableauPiles()]
          # console.log "checking #{i},waste"
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
                    cards: @cloneCards([_.last(@waste)])
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }
    
  commandsForPlayingWasteOnFoundations: ->
    unless _.isEmpty(@waste)
      console.log "Check if we can play waste on foundations"
      unless _.isEmpty(@waste)
        for j in [0..3]
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
                  cards: @cloneCards([_.last(@waste)])
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
                    cards: @cloneCards([_.last(@waste)])
                    guiAction: "drag"
                    initiator: "user"
                  ]
                }
  
  commandsForPlayingFoundationToTableauPiles: ->
    console.log "commandsForPlayingFoundationToTableauPiles"
    for i in [0...@zeroIndexNumberOfTableauPiles()]
      unless _.isEmpty(@faceUpTableauPiles[i])
        for j in [0..3]
          # console.log "#{i}, #{j}"
          unless _.isEmpty(@foundations[j]) || \
              (!_.isEmpty(@foundations[j]) && _.last(@foundations[j]).rank.value < 2)  # don't play aces or 2s
            if @tableauPileAccepts(i,[_.last(@foundations[j])])
              console.log "moving foundation #{j} to tableau #{i}"
              @cmds.push {
                method: 'commandsForPlayingFoundationToTableauPiles', 
                commands: [
                  new App.Models.Command
                    action: 'move'
                    src: ["foundations",j]
                    dest: ["faceUpTableauPiles",i]
                    numberOfCards: 1
                    cards: @cloneCards([_.last(@foundations[j])])
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
        
  possibleCommands: ->
    console.log "Starting nextHintCommand run"
    @cmds = []
    methods = ['commandsForInterTableauPilePlay',
      'commandsForPlayingTableauKingsOnBlanks',
      'commandsForMovingTableauCardsToFoundations',
      'commandsForPlayingWasteOnTableauPiles',
      'commandsForPlayingWasteOnFoundations',
      'commandsForPlayingKingsOnWasteOnTableauPiles',
      'commandsForPlayingFoundationToTableauPiles',
      'commandsForRedealing',
      'commandsForTurningStock']
    for method in methods
      eval("this.#{method}()")
    App.possible_commands = @cmds
    return @cmds
    
  nextHintCommand: ->
    console.log "------------------------------------------------------------------------"
    @possibleCommands()
    console.log "Possible Commands"
    @consoleHintCommands(@cmds)

    console.log "History"
    @consoleLastCommand(2)
    
    @processRules()
    console.log "After Rules"
    @consoleHintCommands(@cmds)

    @cmds = @scoreCmds(@cmds)
    # console.log _.groupBy(@cmds, 'method')
    App.hint_results = @cmds
    return _.first(@cmds).commands unless _.isEmpty(@cmds)
    null   # no move found

  processRules: ->
    rules = ['ruleAlwaysPlayAceOrTwoToFoundations',
      'ruleDontUndoLastAction',
      'ruleDontRepeatLastAction',
      'rulePlayWasteBeforeFoundation',
      'ruleTurnStockBeforePlayingFromFoundation',
      'ruleTurnStockBeforePlayingToFoundation']
    for rule in rules
      res = eval("this.#{rule}()")
      console.log "Rule #{rule}: #{res}"
      break if res
    
  ruleDontUndoLastAction: ->
    console.log "Processing ruleDontUndoLastAction"
    removals = []
    unless _.isEmpty(@undoStack)
      lastCommands = _.last(@undoStack)
      return if @commandsContain(lastCommands, ["turnStock", "redeal"])
      for obj, i in @cmds
        for cmd in obj.commands
          for lcmd in lastCommands
            if @commandName(cmd) == @commandName(lcmd, true)
              removals.push(i)
              break
      for i in removals
        console.log "Removing #{i}"
        @cmds.splice(i,1)
    return true unless _.isEmpty(removals)
    return false

  ruleDontRepeatLastAction: ->
    console.log "Processing ruleDontRepeatLastAction"
    removals = []
    unless _.isEmpty(@undoStack)
      lastCommands = _.last(@undoStack)
      return if @commandsContain(lastCommands, ["turnStock", "redeal"])
      for obj, i in @cmds
        for cmd in obj.commands
          for lcmd in lastCommands
            if @commandName(cmd) == @commandName(lcmd)
              removals.push(i)
              break
      for i in removals
        console.log "Removing #{i}"
        @cmds.splice(i,1)
    return true unless _.isEmpty(removals)
    return false
  
  rulePlayWasteBeforeFoundation: ->
    console.log "Processing rulePlayWasteBeforeFoundation"
    for obj, i in @cmds
      for cmd in obj.commands
        if cmd.src? && cmd.src[0] == "waste"
          console.log "..waste found"
          @moveCommandToFirst(i)
          return true
    return false
  
  ruleTurnStockBeforePlayingFromFoundation: (ret = false) ->
    console.log "Processing ruleTurnStockBeforePlayingFromFoundation"
    if !_.isEmpty(@cmds) && !_.isEmpty(@stock) && \
        @cmds[0].commands[0].src? && \
        @cmds[0].commands[0].src[0] == 'foundations'
      @cmds.splice(0,1)
      @ruleTurnStockBeforePlayingFromFoundation(true)
    return ret

  ruleTurnStockBeforePlayingToFoundation: (ret = false)->
    console.log "Processing ruleTurnStockBeforePlayingToFoundation"
    if !_.isEmpty(@cmds) && !_.isEmpty(@stock) && \
        @cmds[0].commands[0].dest? && \
        @cmds[0].commands[0].dest[0] == 'foundations'
      @cmds.splice(0,1)
      @ruleTurnStockBeforePlayingToFoundation(true)
    return ret
    
  ruleAlwaysPlayAceOrTwoToFoundations: ->
    console.log "Processing ruleAlwaysPlayAceOrTwoToFoundations"
    # if a cmd exists that plays an ace or a two to foundation - delete everything infront of it
    for obj, i in @cmds
      for cmd in obj.commands
        if cmd.src? && cmd.src[0] == 'faceUpTableauPiles' && \
            _.last(@faceUpTableauPiles[cmd.src[1]]).rank.value < 2 && \
            cmd.dest? && cmd.dest[0] == 'foundations'
          console.log "..moving #{i} to front of commands"
          @moveCommandToFirst(i)
          return true
    return false
  
  moveCommandToFirst: (index) ->
    cmd = @cmds.splice(index,1)
    tmp = _.flatten([cmd,@cmds])
    @cmds = tmp
    
  commandsContain: (commands, actions) ->
    for cmd in commands
      for action in actions
        return true if cmd.action == action
    return false
    
  commandsAreReverseOfEachOther: (cmd1, cmd2) ->
    return false unless cmd1.action == cmd2.action
    return false if cmd1.action == "redeal" || cmd1.action == "turnStock" || cmd2.action == "redeal" || cmd2.action == "turnStock"
    if cmd1.dest.length == cmd2.src.length && cmd1.src.length == cmd2.dest.length
      for idx in [0..cmd1.dest.length]
        return false unless cmd1.dest[idx] == cmd2.src[idx]
      for idx in [0..cmd1.src.length]
        return false unless cmd1.src[idx] == cmd2.dest[idx]
    else 
      return false
    return true

  commandName: (cmd, reverse=false) ->
    res = [cmd.action]
    if reverse
      res.push("src:#{cmd.dest.join('-')}") if cmd.dest?
      res.push("dest:#{cmd.src.join('-')}") if cmd.src?
    else
      res.push("src:#{cmd.src.join('-')}") if cmd.src?
      res.push("dest:#{cmd.dest.join('-')}") if cmd.dest?
    res.push("cards:#{cmd.numberOfCards}") if cmd.numberOfCards?
    # assumes card was deepCloned
    if cmd.cards?
      for card in cmd.cards
        res.push(card.display)
        
    return res.join(" ")

  consoleHintCommands: (cmds) ->
    if _.isEmpty(cmds)
      console.log "Empty"
    else
      for obj in cmds
        for cmd in obj.commands
          console.log ">> #{@commandName(cmd)}"
        
  consoleLastCommand: (iCount=1) ->
    if _.isEmpty(@undoStack)
      console.log "Empty"
    else
      iEnd = @undoStack.length
      iStart = @undoStack.length - iCount
      iStart = iEnd if iStart < iEnd
      for i in [iStart..iEnd]
        for cmd in @undoStack[i-1]
          console.log "<< last: #{@commandName(cmd)}"

  executeCommand: (cmd) ->
    super
    @score += @scoreCmd(cmd)
    @moves += 1
    $('#score').text("Score: #{@score}")
    $('#moves').text("Moves: #{@moves}")
      
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
        score += -15 if dest == "faceUpTableauPiles"
    return score
