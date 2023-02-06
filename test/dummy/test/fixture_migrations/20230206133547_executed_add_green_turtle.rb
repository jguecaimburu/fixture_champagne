# frozen_string_literal: true

class ExecutedAddGreenTurtle < FixtureChampagne::Migration::Base
  def up
    return if Character::Turtle.find_by(name: "Greenie Jr").present?

    Character::Turtle::Green.create!(
      name: "Greenie Jr",
      level: levels(:hard),
      history: "I'm not the first green turtle",
      birthday: character_turtles(:greenie).birthday + 4.years
    )
  end

  def down
    Character::Turtle.find_by(name: "Greenie Jr").destroy!
  end
end
