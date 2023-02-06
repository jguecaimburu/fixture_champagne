class PendingAddMushroom < FixtureChampagne::Migration::Base
  def up
    return if Character::Mushroom.find_by(name: "Amarita").present?

    Character::Mushroom.create!(
      name: "Amarita",
      level: levels(:hard),
      collection_time: character_turtles(:greenie).birthday + 4.years
    )
  end

  def down
    Character::Mushroom.find_by(name: "Amarita").destroy!
  end
end
