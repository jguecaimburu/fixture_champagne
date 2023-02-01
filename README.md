# Fixture Champagne :champagne:

### Fixture migrations for your Ruby on Rails applications

WIP: This gem is still unreleased.

Fixture Champagne is designed to help you keep your fixtures tidy, applying the data migration pattern to create, update or destroy fixtures.

It supports label references for belongs_to associations, both regular and polymorphic, single table inheritance, enums and all the different data types.

## Installation

1. Add `fixture-champagne` to the development group of your app's `Gemfile`:

```ruby
group :development do
  gem 'rspec-rails', '~> 6.0.0'
end
```

2. Then, in your project directory:

```sh
# Download and install
$ bundle install

# Generate fixture_migrations folder in your test or spec folder, depending on your test suite
$ bin/rails generate fixture_champagne:install
```

## Usage

### Sync fixtures with schema

If your schema version changed and you need to add any new column to the current fixtures, simply run:

```sh
bin/rails fixture_champagne:migrate
```

The migration process will regenarate your `fixtures` folder.

### Add, update or destroy fixtures

If you need specific values for the new columns or a new table was created, you might find useful to create a migration. This can be done using the generator:

```sh
bin/rails generate fixture_champagne:migration new_migration_name
```

A new versioned migration file will be created in the `fixture_migrations` folder. If this is your first migration, make sure that folder exist or run the installation command.

Active record queries and fixture accessors can be used inside the migrations. For example, let's say you added the `Enemy` model and you need to create new fixture and you have the following files:

```ruby
# models/level.rb

class Level < ApplicationRecord
  has_many :enemies
end

# models/enemy.rb

class Enemy < ApplicationRecord
  belongs_to :level
end
```

```yaml
# test/fixtures/levels.yml

first_level:
  name: Initial
```

You could create, edit and run a new migration:

```sh
bin/rails generate fixture_champagne:migration create_initial_enemy
```

The generator automatically adds a version number to the new migration file, which is important to keep track of executed migrations. Also, the migration filename must correspond with the migration class inside the file. All this should feel similar to the way schema migrations are handled by Rails.

```ruby
# 20230126153650_create_initial_enemy.rb

class CreateInitialEnemy < FixtureChampagne::Migration::Base
  def up
    unless Enemy.find_by(name: "Initial Enemy").present?
      Enemy.create!(name: "Initial Enemy", level: levels(:first_level)) 
    end
  end

  def down
    Enemy.find_by(name: "Initial Enemy").destroy!
  end
end
```

Running `bin/rails fixture_champagne:migrate` will run all pending migrations in ascending version number order to update the test database. The fixture folder is regenerated only once after all the migrations where successfully executed. In this case, it would generate the following file:

```yaml
# test/fixtures/enemies.yml

enemies_12345678:
  level: first_level
  name: Initial Enemy
```

Max version number and current schema version get saved in `.fixture_champagne_versions.yml`, inside application test suite folder, to identify future pending migrations.

The default label for a new fixture is a unique identifier composed of the table name and the record id. However, this label can be configured (keep reading to know how).

### Rollback

You can optionally complete the `down` method in the migration to allow it's rollback. Running the following command will rollback the last executed migration:

```sh
bin/rails fixture_champagne:rollback
```

New max version will be set to the next one in descending order. Schema version won't change.

### Configuration

You can better control fixture migrations by creating a `fixture_champagne.yml` file inside your test suite folder.

#### Overwrite current fixtures

Setting the `overwrite` key to `false` will leave your current fixtures untouched. The generated fixtures will go to `tmp/fixtures`. Default value is set to `true`.

```yaml
# test/fixture_champagne.yml

overwrite: false
```

#### Fixture labels

Setting the `label` key allow you to control the names your fixture get. It accepts a hash, where keys are table names and values are label templated, interpolated in a I18n gem style syntax. Interpolated keywords must be model methods or attributes.

In the previous example, you can configure:

```yaml
# test/fixture_champagne.yml

label:
  enemy: "%{name}"    
```

To generate:

```yaml
# test/fixtures/enemies.yml

initial_enemy:
  level: first_level
  name: Initial Enemy
```

#### Rename current fixtures

Setting the `rename` key to `true` will force every fixture label to follow the templates configured in the `label` key. Default value is `false`. If any table is not configured, the default label will be used (`%{table_name}_%{id}`).

If `rename` is set to `true`, every time you run `migrate` or `rollback`, all fixtures will be regenerated in the corresponding folder (depending on `overwrite`), even if there's no pending migration or schema is unchanged. Keep in mind that a renaming might break the fixture accessors in your tests or previous migrations.

```yaml
# test/fixture_champagne.yml

rename: true
```

#### Ignore tables

Setting the `ignore` key allow you to control which tables get saved as fixtures. It accepts an array, where items are table names. Any table ignored by this configuration will disappear from the corresponding fixture folder (depending on `overwrite`).

Let's say for example that each time a new `Enemy` is created, you create an associated `Event` that runs some processing in the background. If that event belongs to a polymorphic `eventable` every time you create one of those, a new event will be added to your fixtures, making the `events.yml` a big but not very useful file. Or maybe events get incinerated a couple of days after execution and makes no sense to have fixtures for them. In any of those situations, you could ignore them from fixtures like this:  

```yaml
# test/fixture_champagne.yml

ignore:
  - events
```

This configuration does not change the shape of the database after the migrations (for example, events will be created anyway) but next time fixtures get loaded, no item from ignored tables will be present. This could break the integrity of your database, so make sure everything is working afterwards.

### Manually adding or editing fixtures

Nothing prevents you to manually edit your fixtures. Take into account that the next time that you run migrations, what's on your fixtures will define the initial state of your migration database, which could break previous migrations or rollbacks. Running a migration will only tidy the information you add.

### Generated fixture folder

On namespaced models, the migrator will create a folder for each level and a `.yml` file for the last one. For example, `Level::Enemy` fixtures will be saved in `fixtures/level/enemies.yml`.

If you use single table inheritance, then the file will correspond with the parent model. For example, `class Weapon::Rocket < Weapon; end` will be saved in `fixtures/weapons.yml`.


## Currently not supported

The following fixture features are not supported:
- Dynamic ERB fixtures (considered a code smell in the [Rails documentation](https://edgeapi.rubyonrails.org/classes/ActiveRecord/FixtureSet.html))
- Explicit `created_at` or `updated_at` timestamps (favoured autofilled ones)
- Explicit `id` (favoured label references)
- Fixture label interpolation (favoured labels gem config)
- HABTM associations as inline lists
- Support for YAML defaults (this could be nice)

##  A few soft recommendations

### Don't have too many fixtures

The goal of this gem is to make it easier to keep fixtures tidy and up to date as things start to get complicated so that factories aren't your only option. But no gem can replace good ol' discipline. If a new fixture gets added for every single small feature or bugfix, manteinance will be hard no matter the tool.

Reduce repetition, reuse fixtures using helpers or use factories for some of your tests.

### Make your migrations idempotent

The `.fixture_champagne_versions.yml` is there to ensure that your migrations are only executed once, but it would be a good idea to design your migrations to be idempotent, meaning that executing them more than once does not change the results.

### Raise errors

Raise errors to stop the migration if there are invalid objects. A good way to do that is using `ActiveRecord` bang methods `create!`, `update!` and `destroy!`.

### Run migrations in independent commits

The safest way to rollback any migration will be to checkout your git changes or revert a commit.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Feel free to open an issue if you have any doubt, suggestion or find buggy behaviour. If it's a bug, it would be great if you can provide a minimum Rails app that reproduces the problem.

This project uses [Rubocop](https://github.com/rubocop/rubocop) to format Ruby code. Please make sure to run `rubocop` on your branch before submitting pull requests. You can do that by running `bundle exec rubocop -A`.

Also run the test suite `bin/rake test`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FixtureChampagne project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/fixture_champagne/blob/master/CODE_OF_CONDUCT.md).
