# frozen_string_literal: true

class AddInitialTables < ActiveRecord::Migration[7.0]
  def change
    create_table :levels do |t|
      t.string :name
      t.string :difficulty
      t.boolean :unlocked

      t.timestamps
    end

    create_table :character_turtles do |t|
      t.string :name
      t.references :level
      t.string :type
      t.date :birthday
      t.text :history

      t.timestamps
    end

    create_table :character_mushrooms do |t|
      t.string :name
      t.references :level
      t.datetime :collection_time

      t.timestamps
    end

    create_table :weaponizable_weapons do |t|
      t.references :weaponizable, polymorphic: true
      t.string :type
      t.integer :power
      t.float :precision

      t.timestamps
    end
  end
end
