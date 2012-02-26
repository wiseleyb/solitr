# Development helpers

window._assert = (exp, messages...) ->
  unless exp
    p 'Assertion failed'
    p messages...
    throw 'Runtime error'

window._fail = (messages...) ->
  _assert(false, messages...)

window.p = (expressions...) ->
  for exp in expressions
    console.log(window.x = exp)
