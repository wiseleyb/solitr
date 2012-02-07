This is the source code for [solitr.com](http://www.solitr.com/).

It is licensed under the MIT License.

To-Do:

* Auto-play won animations
* You win, play again
* Select game type
* Mouse cursor

Bugs:

* Clicking the stock very fast can in rare cases cause a double-click to
  trigger on the topmost card which then gets played instantly. Should we
  perhaps delay the event binding?
* Strange delay moving stock card into place when auto-won.
