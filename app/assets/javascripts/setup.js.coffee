window.App ?= {}
App.rootElement = '#solitaireCanvas'
App.Models ?= {}

# Development helpers

window.assert = (exp, messages...) ->
  unless exp
    p 'Assertion failed'
    p messages...
    throw 'Runtime error'

window.fail = (messages...) ->
  assert(false, messages...)

window.p = (expressions...) ->
  for exp in expressions
    console.log(window.x = exp)
