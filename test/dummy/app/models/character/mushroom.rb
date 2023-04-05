# frozen_string_literal: true

class Character
  class Mushroom < Character
    has_one_attached :profile_pic

    # Support Rails >= 6.0.0
    encrypts :code_name if respond_to?(:encrypts)
  end
end
