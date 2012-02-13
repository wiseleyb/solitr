#= require vendor
#= require jquery_ujs
#= require twitter/bootstrap/dropdown
#= require twitter/bootstrap/modal
#= require_tree .

$ ->
  # Remove missing modal links
  for e in $('.navbar a[data-toggle=modal]')
    unless $($(e).attr 'href').length
      $(e).remove()
