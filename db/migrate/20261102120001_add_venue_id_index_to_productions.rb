class AddVenueIdIndexToProductions < ActiveRecord::Migration[6.1]
  # Venue#now_playing and #now_playing_or_next_up (the public now-playing
  # widgets) query productions by venue_id, which otherwise full-scans.
  def change
    add_index :productions, :venue_id
  end
end
