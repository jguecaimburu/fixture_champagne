# frozen_string_literal: true

class Character
  class Mushroom < Character
    has_one_attached :profile_pic
  end
end
