This is the source code for [solitr.com](http://www.solitr.com/).

It is licensed under the MIT License.

To-Do:

* Show free spaces in tableaux
* Auto-play won
* Undo
* You win, play again
* Select game type
* Animations

Bugs:

* Double-click-then-drag a playable card, and it snaps back to its original
  location while the gameState has it played. Need to make sure our animations
  don't interfere with positioning.
* Clicking the stock very fast can cause a double-click to trigger on the
  topmost card which then gets played instantly.
