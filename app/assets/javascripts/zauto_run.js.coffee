
class App.Timer 
  timers: []
  clearTimers: ->
    for timer in @timers
      timer.call @
    @timers = []
  addInterval: (callback, ms) ->
    id = setInterval callback, ms
    @timers.push ->
      clearInterval id
    id
  addTimeout: (callback, ms) ->
    id = setTimeout callback, ms
    @timers.push ->
      clearTimeout id
    id

class App.AutoRun

  # requesting: false
  paused: false

  constructor: ->
    @timer = new App.Timer
    
  poll: ->
    @update()
    @timer.addInterval (=>(@update())), 100
  

  update: ->
    unless @requesting || @paused
      console.log "Updating..."
      App.gameController.hint()
      # @requesting = true
      # @ajax (xhr, status) =>
      #   @requesting = false

  pause: ->
    console.log "pause request"
    @paused = true

  unpause: ->
    console.log "unpause request"
    @paused = false

  tearDown: ->
    @timer.clearTimers()

