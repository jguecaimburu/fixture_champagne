# frozen_string_literal: true

class Level < ApplicationRecord
  enum difficulty: { easy: "easy", medium: "medium", hard: "hard" }
end
