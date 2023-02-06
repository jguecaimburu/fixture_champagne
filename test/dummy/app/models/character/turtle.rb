# frozen_string_literal: true

class Character
  class Turtle < Character
    include Weaponizable

    def level_name
      level.name
    end
  end
end
