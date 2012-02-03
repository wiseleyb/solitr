window.App = Ember.Application.create
  rootElement: '#solitaire-canvas'

App.Models ||= {}
App.Controllers ||= {}
App.Views ||= {}

# Development helpers

window.assert = (exp, msg) ->
  throw (msg || 'Runtime error') unless exp

window.fail = (msg) ->
  assert(false, msg)

window.p = (exp) ->
  console.log(exp)
