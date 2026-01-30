class MigrateApiKeysToTeams < ActiveRecord::Migration[8.2]
  def up
    # Generate API key for each team without one
    execute <<-SQL
      UPDATE teams
      SET api_key = lower(hex(randomblob(32)))
      WHERE api_key IS NULL
    SQL

    # Make api_key not null after populating
    change_column_null :teams, :api_key, false
  end

  def down
    change_column_null :teams, :api_key, true
  end
end
