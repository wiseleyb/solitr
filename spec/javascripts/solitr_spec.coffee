require '/assets/application.js'

describe 'Card', ->
  it 'should assign different ids', ->
    expect(Card.create(0, 0, false).id).not.toEqual(Card.create(0, 0, false).id)
