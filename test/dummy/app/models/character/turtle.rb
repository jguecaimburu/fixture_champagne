# frozen_string_literal: true

class Character
  class Turtle < Character
    include Weaponizable

    def hide
      p "#{model_name} #{id} hid"
    end

    def level_name
      level.name
    end
  end
end
