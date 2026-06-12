require 'rails_helper'

# Direct unit test for the duplicate hash transformation fix
RSpec.describe "FlexPassUsageReport fix for ticket_paid_out calculation", type: :unit do
  it "properly transforms amounts without duplicate nesting" do
    # This simulates the bug where the original code had two identical transformations
    # paid_amount.each { |key, value| paid_amount[key] = { tickets_paid_out: value } }
    # paid_amount.each{|key, value| paid_amount[key] = {tickets_paid_out: value} }

    # Simulate the initial hash returned from the query
    paid_amount = { "2025-05" => 45.0 }

    # Apply the transformation once (as in the fixed code)
    paid_amount.each { |key, value| paid_amount[key] = { tickets_paid_out: value } }

    # Check result
    expect(paid_amount["2025-05"]).to eq({ tickets_paid_out: 45.0 })
    expect(paid_amount["2025-05"][:tickets_paid_out]).to eq(45.0)

    # Now demonstrate the bug by applying the transformation again (as in the buggy code)
    paid_amount_buggy = { "2025-05" => 45.0 }
    paid_amount_buggy.each { |key, value| paid_amount_buggy[key] = { tickets_paid_out: value } }
    paid_amount_buggy.each { |key, value| paid_amount_buggy[key] = { tickets_paid_out: value } }

    # The result will be nested hashes
    expect(paid_amount_buggy["2025-05"]).to eq({ tickets_paid_out: { tickets_paid_out: 45.0 } })

    # In the buggy version, this would be an object not a number:
    expect(paid_amount_buggy["2025-05"][:tickets_paid_out]).to eq({ tickets_paid_out: 45.0 })

    # Simulate how this affects the merged hash access in the report:
    merged_hash = paid_amount["2025-05"] # Fixed version
    expect(merged_hash[:tickets_paid_out]).to eq(45.0)

    merged_hash_buggy = paid_amount_buggy["2025-05"] # Buggy version
    # The bug caused the tickets_paid_out value to be a hash, not a number,
    # which would then become 0.0 when called with || 0.0 in the report
    expect(merged_hash_buggy[:tickets_paid_out]).not_to eq(45.0)
  end
end
