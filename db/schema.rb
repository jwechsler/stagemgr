# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_07_02_210300) do

  create_table "active_storage_attachments", charset: "utf8mb3", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb3", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "address_tags", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "address_id"
    t.integer "theater_id"
    t.string "tag_label"
    t.string "tag_value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["address_id"], name: "address_tags_to_address"
    t.index ["theater_id"], name: "address_tags_to_theater"
  end

  create_table "addresses", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "line1"
    t.string "line2"
    t.string "city"
    t.string "state"
    t.string "zipcode"
    t.boolean "on_mailing_list"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "phone"
    t.integer "add_to_mail_list"
    t.string "street_number"
    t.string "street"
    t.string "street_type"
    t.string "unit"
    t.string "unit_prefix"
    t.string "search_name"
    t.datetime "sf_last_sync_at"
    t.string "full_name"
    t.string "middle_name"
    t.string "prefix"
    t.integer "sf_purge"
    t.string "sf_contact_id"
    t.boolean "placeholder", default: false
    t.boolean "vip"
    t.string "last_first_name"
    t.string "processor_id"
    t.string "donor_tier_for_last_fiscal_year"
    t.string "donor_tier_for_current_fiscal_year"
    t.date "donor_tier_updated_on"
    t.index ["first_name"], name: "index_addresses_on_first_name"
    t.index ["last_first_name"], name: "index_addresses_on_last_first_name"
    t.index ["last_name"], name: "index_addresses_on_last_name"
    t.index ["search_name", "email"], name: "index_addresses_on_search_name_and_email"
    t.index ["street_number", "street", "city", "search_name"], name: "index_address_search"
  end

  create_table "addresses_productions", id: false, charset: "latin1", force: :cascade do |t|
    t.integer "address_id"
    t.integer "production_id"
    t.index ["address_id", "production_id"], name: "index_addresses_productions_on_address_id_and_production_id"
  end

  create_table "audits", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.datetime "created_at"
    t.string "request_uuid"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "default_ticket_classes", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "class_code"
    t.string "class_name"
    t.string "description"
    t.integer "minutes_before_show"
    t.decimal "ticket_price", precision: 6, scale: 2
    t.string "ticket_type"
    t.decimal "ticketing_fee", precision: 6, scale: 2
    t.boolean "web_visible"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "auto_attach"
    t.boolean "software_managed"
    t.boolean "holds_seats", default: true
    t.string "purchase_page_annotation"
    t.text "purchase_email_annotation"
    t.boolean "assigns_seats", default: false
    t.boolean "show_in_pricing_range", default: true
    t.boolean "suppress_receipt"
    t.boolean "hide_pricing"
    t.boolean "complimentary", default: false
    t.boolean "exchangeable", default: false
    t.decimal "royalty_amount", precision: 8, scale: 2
  end

  create_table "file_stores", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "user_id"
    t.text "notes"
    t.string "worker"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "format"
    t.index ["user_id"], name: "index_file_stores_on_user_id"
  end

  create_table "flex_pass_offers", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "theater_id"
    t.decimal "price", precision: 8, scale: 2, null: false
    t.integer "number_of_tickets"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.boolean "active", default: true, null: false
    t.boolean "exclude_theater", default: false, null: false
    t.boolean "redeem_immediately"
    t.text "description"
    t.string "short_description"
    t.decimal "facility_fee", precision: 8, scale: 2
    t.decimal "spiff", precision: 8, scale: 2
    t.decimal "flat_payout", precision: 8, scale: 2
    t.string "use_ticket_class_code"
    t.integer "months_till_expiration", default: 12
    t.boolean "treat_as_festival_pass"
    t.boolean "on_sale_to_public", default: false
    t.string "code_prefix"
    t.integer "maximum_uses_per_production"
  end

  create_table "flex_passes", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "code"
    t.integer "address_id"
    t.integer "flex_pass_offer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "flex_pass_line_item_id"
    t.date "expiration_date"
    t.boolean "active", default: true
  end

  create_table "house_counts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "performance_id", null: false
    t.integer "total_seats", default: 0, null: false
    t.integer "sold_seats", default: 0, null: false
    t.integer "available_seats", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "held_seats", default: 0, null: false
    t.decimal "max_ticket_price", precision: 8, scale: 2
    t.boolean "sold_out", default: false, null: false
    t.boolean "near_capacity", default: false, null: false
    t.decimal "min_ticket_price", precision: 8, scale: 2
    t.index ["performance_id"], name: "index_house_counts_on_performance_id"
  end

  create_table "job_metadata", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "job_name"
    t.datetime "last_run_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "line_items", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "ticket_class_id"
    t.integer "order_id"
    t.integer "ticket_count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "type"
    t.integer "special_offer_id"
    t.integer "flex_pass_offer_id"
    t.integer "membership_id"
    t.integer "membership_offer_id"
    t.integer "address_id"
    t.float "facility_fee"
    t.string "description"
    t.string "internal_description"
    t.boolean "generated_from_split"
    t.decimal "price_override", precision: 8, scale: 2
    t.decimal "amount", precision: 8, scale: 2, default: "0.0"
    t.boolean "suppress_for_pass_payments", default: false
    t.integer "seat_assignment_id"
    t.index ["order_id"], name: "line_items_oid_i"
    t.index ["seat_assignment_id"], name: "index_line_items_on_seat_assignment_id", unique: true
    t.index ["ticket_class_id"], name: "line_items_to_ticket_class"
  end

  create_table "membership_offers", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.text "email_html"
    t.string "use_ticket_class_code"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "tickets_per_performance"
    t.text "html_description"
    t.text "billing_agreement"
    t.string "myemma_group"
    t.string "use_member_friend_code"
    t.boolean "on_sale", default: true
    t.integer "trial_period", default: 0
    t.boolean "restricted_to_first_time", default: false
    t.integer "max_cycles_if_gift"
    t.string "status", default: "Active"
    t.string "price_id"
  end

  create_table "memberships", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "membership_offer_id"
    t.date "member_since"
    t.integer "address_id"
    t.string "member_code"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "profile_id"
    t.integer "cycles_active"
    t.decimal "aggregate_amount", precision: 10, scale: 2
    t.date "next_billing_date"
    t.string "preferred_seating", default: "Best available (center)"
    t.date "final_payment_due_date"
    t.integer "total_billing_cycles"
    t.float "recurring_amount"
    t.date "start_date"
    t.date "ended_at"
    t.boolean "cancel_at_period_end", default: false
  end

  create_table "order_task_suppressions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "task_type"
    t.string "method_name"
    t.integer "payment_type_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_tasks", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "execute_at"
    t.integer "order_id"
    t.string "type"
    t.string "status"
    t.integer "attempts"
    t.string "method_symbol"
    t.text "result"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "repeat_monthly_interval"
    t.string "notifications"
    t.index ["order_id"], name: "fk_order_tasks"
  end

  create_table "orders", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "notes"
    t.integer "address_id"
    t.string "special_offer_code"
    t.string "ip_address"
    t.integer "theater_id"
    t.string "type", default: "Order"
    t.string "marketing_source"
    t.integer "print_order_id"
    t.datetime "sf_last_sync_at"
    t.string "special_request"
    t.string "sf_order_id"
    t.boolean "gift", default: false
    t.string "recipient_name"
    t.string "recipient_email"
    t.date "gift_date"
    t.integer "recipient_address_id"
    t.string "campaign", default: "Online"
    t.integer "payment_type_id"
    t.string "hold_under"
    t.integer "exchange_source_id"
    t.string "uuid", null: false
    t.integer "split_source_id"
    t.boolean "suppress_receipt", default: false
    t.index ["address_id"], name: "address_owns_orders"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["exchange_source_id"], name: "index_orders_on_exchange_source_id"
    t.index ["id"], name: "orders_id_i"
    t.index ["performance_id"], name: "index_orders_on_performance_id"
    t.index ["recipient_address_id"], name: "recipient_address_id_idx"
    t.index ["split_source_id"], name: "index_orders_on_split_source_id"
    t.index ["uuid"], name: "index_orders_on_uuid", unique: true
  end

  create_table "payment_restrictions", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.integer "payment_type_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "payment_types", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "display_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "type"
    t.boolean "allow_for_public", default: false
    t.boolean "allow_for_box_office", default: true
    t.string "restrict_to_ticket_classes"
    t.boolean "report_as_sales_collected", default: true
    t.boolean "allow_theater_user_holds", default: false
    t.boolean "report_as_production_revenue", default: true
  end

  create_table "payments", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "card_last_four"
    t.string "card_type"
    t.integer "card_expiration_year"
    t.integer "card_expiration_month"
    t.string "confirmation_code"
    t.integer "order_id"
    t.integer "payment_id"
    t.string "type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "address_id"
    t.string "note"
    t.integer "flex_pass_id"
    t.integer "number_of_tickets"
    t.string "ip_address"
    t.string "transaction_id"
    t.integer "membership_id"
    t.datetime "processed_on"
    t.string "ipn_track_id"
    t.integer "payment_type_id"
    t.integer "source_payment_type_id"
    t.decimal "processing_fee", precision: 8, scale: 2
    t.decimal "amount", precision: 8, scale: 2, default: "0.0"
    t.index ["ipn_track_id"], name: "index_payments_on_ipn_track_id"
    t.index ["membership_id"], name: "index_payments_on_membership_id"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["order_id"], name: "payments_oid_i"
    t.index ["transaction_id"], name: "index_payments_on_transaction_id"
  end

  create_table "performance_broadcasts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "performance_id", null: false
    t.integer "user_id", null: false
    t.string "subject", null: false
    t.string "from_address", null: false
    t.text "body", null: false
    t.integer "recipient_count"
    t.datetime "sent_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["performance_id"], name: "index_performance_broadcasts_on_performance_id"
    t.index ["sent_at"], name: "index_performance_broadcasts_on_sent_at"
    t.index ["user_id"], name: "index_performance_broadcasts_on_user_id"
  end

  create_table "performances", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "production_id"
    t.date "performance_date"
    t.time "performance_time"
    t.string "status"
    t.string "performance_code"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "suppress_notification", default: false
    t.text "special_feature_display_markdown"
    t.text "special_feature_email_markdown"
    t.string "order_url_override"
    t.boolean "withhold_from_public", default: false
  end

  create_table "performances_special_features", id: false, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.integer "special_feature_id"
  end

  create_table "performances_ticket_classes", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.integer "ticket_class_id"
  end

  create_table "pledges", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "order_id"
    t.string "profile_id"
    t.integer "address_id"
    t.integer "cycles_active"
    t.decimal "aggregate_amount", precision: 10, scale: 2
    t.date "next_billing_date"
    t.integer "failed_payment_count"
    t.integer "number_cycles_completed"
    t.decimal "outstanding_balance", precision: 10, scale: 2
    t.string "status"
    t.date "final_payment_due_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "number_cycles_remaining"
    t.integer "total_billing_cycles"
    t.float "recurring_amount"
    t.index ["address_id"], name: "index_pledges_on_address_id"
    t.index ["order_id"], name: "index_pledges_on_order_id"
    t.index ["profile_id"], name: "index_pledges_on_profile_id"
  end

  create_table "productions", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.text "credit_lines"
    t.date "first_preview_at"
    t.date "press_opening_at"
    t.date "opening_at"
    t.date "closing_at"
    t.text "show_description"
    t.string "production_code"
    t.integer "capacity"
    t.string "additional_information_link"
    t.string "status", default: "---\n:from: \n:to: Inactive\n"
    t.integer "theater_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "logo_url"
    t.string "myemma_attendee_group"
    t.integer "running_time"
    t.boolean "intermission", default: true
    t.integer "flex_pass_offer_id"
    t.text "follow_up_message"
    t.text "follow_up_text"
    t.text "confirmation_message"
    t.text "follow_up_message_2"
    t.string "production_class", default: "Play"
    t.integer "venue_id"
    t.string "short_description"
    t.integer "season"
    t.boolean "allow_late_seating", default: false
    t.datetime "sf_last_sync_at"
    t.text "conversion_pixel_code"
    t.text "calendar_callout"
    t.string "survey_link"
    t.string "mailing_list_link"
    t.string "custom_label"
    t.integer "seat_map_id"
    t.string "override_service_items"
    t.string "override_first_exchange_items"
    t.string "override_addl_exchange_items"
    t.string "custom1"
    t.string "custom2"
    t.decimal "royalty_percent", precision: 5, scale: 2
    t.integer "allocation_sync_pending_count", default: 0, null: false
    t.index ["production_code"], name: "index_productions_on_production_code"
    t.index ["seat_map_id"], name: "index_productions_on_seat_map_id"
  end

  create_table "rate_of_sales", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.date "day_of_sale"
    t.integer "production_id", null: false
    t.integer "total_single_tickets"
    t.integer "total_complimentary_tickets"
    t.decimal "gross_sales", precision: 8, scale: 2
    t.decimal "processing_fees", precision: 8, scale: 2
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "order_count", default: 0, null: false
    t.decimal "ticketing_fees", precision: 8, scale: 2
    t.index ["day_of_sale", "production_id"], name: "index_rate_of_sales_on_day_of_sale_and_production_id", unique: true
    t.index ["production_id"], name: "fk_rails_e797c43455"
  end

  create_table "seat_assignments", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.integer "order_id"
    t.integer "seat_id"
    t.integer "performance_id"
    t.string "status", default: "Available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ticket_class_id"
    t.string "order_uuid"
    t.string "accessibility"
    t.decimal "price_override", precision: 8, scale: 2
    t.index ["order_id"], name: "index_seat_assignments_on_order_id"
    t.index ["order_uuid"], name: "index_seat_assignments_on_order_uuid"
    t.index ["performance_id"], name: "index_seat_assignments_on_performance_id"
    t.index ["seat_id"], name: "index_seat_assignments_on_seat_id"
    t.index ["status", "updated_at"], name: "seat_assignments_on_updated_and_status"
  end

  create_table "seat_assignments_recovery", id: :integer, default: 0, charset: "utf8mb3", force: :cascade do |t|
    t.integer "order_id"
    t.integer "seat_id"
    t.integer "seat_map_id"
    t.integer "performance_id"
    t.string "status", default: "Available"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "seat_maps", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "label"
    t.integer "venue_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "present_as_zoned", default: false, null: false
    t.index ["venue_id"], name: "index_seat_maps_on_venue_id"
  end

  create_table "seats", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "location", null: false
    t.string "zone", default: "A", null: false
    t.string "row", null: false
    t.integer "seat_number", null: false
    t.integer "seat_map_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "origin_x"
    t.integer "origin_y"
    t.integer "width"
    t.integer "height"
    t.string "feature"
    t.index ["seat_map_id"], name: "index_seats_on_seat_map_id"
  end

  create_table "service_item_templates", id: :integer, charset: "utf8mb3", force: :cascade do |t|
    t.string "name"
    t.string "description", null: false
    t.float "amount"
    t.float "facility_fee"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "internal_description"
    t.boolean "user_selectable", default: true
    t.boolean "suppress_for_pass_payments", default: false
    t.index ["name"], name: "index_service_item_templates_on_name", unique: true
  end

  create_table "sessions", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_request_at"
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "special_features", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "short_name"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "status", default: "Active"
  end

  create_table "special_offers", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.integer "production_id"
    t.integer "theater_id"
    t.float "amount", default: 0.0
    t.string "type"
    t.string "code"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "number_of_uses"
    t.date "auto_expire"
    t.string "status", default: "Active"
    t.string "ticket_class_code"
    t.boolean "system_generated", default: false
    t.string "change_ticket_class_code"
    t.integer "max_tickets_per_order", default: 0
    t.integer "membership_id"
    t.datetime "auto_start"
    t.date "performance_start_range"
    t.date "performance_end_range"
    t.integer "day_restrictions", default: 0
    t.index ["code"], name: "index_special_offers_on_code"
    t.index ["performance_id"], name: "index_special_offers_on_performance_id"
    t.index ["production_id"], name: "index_special_offers_on_production_id"
    t.index ["system_generated"], name: "index_special_offers_on_system_generated"
    t.index ["theater_id"], name: "index_special_offers_on_theater_id"
  end

  create_table "theater_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "theater_id", null: false
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_theater_tags_on_name"
    t.index ["theater_id"], name: "index_theater_tags_on_theater_id"
  end

  create_table "theaters", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.string "theater_class"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "default_service_items"
    t.string "default_first_exchange_items"
    t.string "default_addl_exchange_items"
    t.string "myemma_attendee_group"
    t.boolean "accepts_donations", default: false
  end

  create_table "theaters_users", id: false, charset: "latin1", force: :cascade do |t|
    t.integer "theater_id"
    t.integer "user_id"
  end

  create_table "ticket_class_allocations", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "performance_id"
    t.integer "ticket_class_id"
    t.boolean "available"
    t.integer "ticket_limit"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "shiftable", default: false
    t.string "shift_to_code"
    t.integer "shift_days_before_performance"
    t.integer "shift_when_capacity_over"
    t.index ["performance_id", "ticket_class_id"], name: "index_tca_on_performance_and_ticket_class"
  end

  create_table "ticket_classes", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "class_code"
    t.string "class_name"
    t.boolean "web_visible"
    t.string "ticket_type"
    t.integer "minutes_before_show"
    t.integer "production_id"
    t.string "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "auto_attach"
    t.boolean "software_managed"
    t.boolean "holds_seats", default: true
    t.string "purchase_page_annotation"
    t.text "purchase_email_annotation"
    t.boolean "assigns_seats", default: false
    t.boolean "show_in_pricing_range", default: true
    t.boolean "suppress_receipt", default: false
    t.boolean "hide_pricing"
    t.boolean "complimentary", default: false
    t.boolean "exchangeable", default: false
    t.decimal "ticketing_fee", precision: 8, scale: 2, default: "0.0"
    t.decimal "ticket_price", precision: 8, scale: 2, default: "0.0"
    t.decimal "royalty_amount", precision: 8, scale: 2
    t.string "zone_id", limit: 2, default: "*", null: false
  end

  create_table "users", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "email", null: false
    t.string "crypted_password", null: false
    t.string "password_salt", null: false
    t.string "persistence_token", null: false
    t.string "single_access_token", null: false
    t.string "perishable_token", null: false
    t.boolean "is_administrator", null: false
    t.boolean "is_box_office_user", null: false
    t.integer "login_count", default: 0, null: false
    t.integer "failed_login_count", default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "current_login_at"
    t.datetime "last_login_at"
    t.string "current_login_ip"
    t.string "last_login_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "status", default: "Active"
    t.string "role"
    t.index ["email"], name: "index_users_on_email"
    t.index ["perishable_token"], name: "index_users_on_perishable_token"
  end

  create_table "venues", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "ordinal_sort"
    t.boolean "external", default: false, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "address_tags", "addresses", name: "address_tags_to_address", on_delete: :cascade
  add_foreign_key "address_tags", "theaters", name: "address_tags_to_theater", on_delete: :cascade
  add_foreign_key "house_counts", "performances"
  add_foreign_key "line_items", "orders", name: "line_items_to_orders", on_delete: :cascade
  add_foreign_key "line_items", "ticket_classes", name: "line_items_to_ticket_class"
  add_foreign_key "order_tasks", "orders", name: "fk_order_tasks", on_delete: :cascade
  add_foreign_key "payments", "orders", name: "payments_to_orders", on_delete: :cascade
  add_foreign_key "performance_broadcasts", "performances"
  add_foreign_key "performance_broadcasts", "users"
  add_foreign_key "rate_of_sales", "productions"
  add_foreign_key "theater_tags", "theaters", on_delete: :cascade
end
