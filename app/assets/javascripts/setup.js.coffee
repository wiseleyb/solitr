window.App ?= {}
App.rootElement = '#solitaire-canvas'
App.Models ?= {}

# Development helpers

window.assert = (exp, msg) ->
  throw (msg || 'Runtime error') unless exp

window.fail = (msg) ->
  assert(false, msg)

window.p = (exp) ->
  console.log(exp)
