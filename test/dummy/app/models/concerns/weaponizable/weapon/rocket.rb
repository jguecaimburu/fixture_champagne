# frozen_string_literal: true

module Weaponizable
  class Weapon
    class Rocket < Weapon
      def shoot
        p "Boom"
      end
    end
  end
end
