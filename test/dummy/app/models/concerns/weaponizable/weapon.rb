# frozen_string_literal: true

module Weaponizable
  class Weapon < ApplicationRecord
    belongs_to :weaponizable, polymorphic: true

    def shoot
      raise "Should implement shoot"
    end
  end
end
