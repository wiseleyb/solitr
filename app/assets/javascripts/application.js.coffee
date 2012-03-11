#= require vendor
#= require twitter/bootstrap/dropdown
#= require twitter/bootstrap/modal
#= require_tree .

$ ->
  # Remove missing modal links
  for e in $('.navbar a[data-toggle=modal]')
    unless $($(e).attr 'href').length
      $(e).remove()

window.timer = new App.AutoRun
window.timers = []