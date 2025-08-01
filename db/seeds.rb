# This file should contain all the record creation needed to seed the database with demo values.
# The data can then be loaded with `rails db:seed` (or along with the creation of the db with `rails db:setup`).

if Rails.env.production?
  Rails.logger.info "Database seeding has been configured to work only in non production settings"
  return
end

# ----------------------------------------------------------------------------
# Random Record Generators
# ----------------------------------------------------------------------------
load "lib/dispersed_past_dates_generator.rb"

def random_record_for_org(org, klass)
  klass.where(organization: org).all.sample
end

# ----------------------------------------------------------------------------
# Script-Global Variables
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Base Items
# ----------------------------------------------------------------------------

require "seeds"
Seeds.seed_base_items

# ----------------------------------------------------------------------------
# NDBN Members
# ----------------------------------------------------------------------------
seed_file = Rails.root.join("spec", "fixtures", "ndbn-small-import.csv").open
SyncNDBNMembers.upload(seed_file)

# ----------------------------------------------------------------------------
# Organizations
# ----------------------------------------------------------------------------

pdx_org = Organization.find_or_create_by!(name: "Pawnee Diaper Bank") do |organization|
  organization.street = "P.O. Box 22613"
  organization.city = "Pawnee"
  organization.state = "IN"
  organization.zipcode = "12345"
  organization.email = "info@pawneediaper.org"
end
Organization.seed_items(pdx_org)

sf_org = Organization.find_or_create_by!(name: "SF Diaper Bank") do |organization|
  organization.street = "P.O. Box 12345"
  organization.city = "San Francisco"
  organization.state = "CA"
  organization.zipcode = "90210"
  organization.email = "info@sfdiaperbank.org"
end
Organization.seed_items(sf_org)

sc_org = Organization.find_or_create_by!(name: "Second City Essentials Bank") do |organization|
  organization.street = Faker::Address.street_address
  organization.city = Faker::Address.city
  organization.state = Faker::Address.state_abbr
  organization.zipcode = Faker::Address.zip_code
  organization.email = "info@scdiaperbank.org"
end
Organization.seed_items(sc_org)

# The list of organizations that will have donations, purchases, requests, distributions,
# and the records those rely on generated.
complete_orgs = [pdx_org, sc_org]

# At least one of the items is marked as inactive
Organization.all.find_each do |org|
  org.items.order(created_at: :desc).last.update(active: false)
end

def seed_random_item_with_name(organization, name)
  base_items = BaseItem.all.map(&:to_h)
  base_item = Array.wrap(base_items).sample
  base_item[:name] = name
  organization.seed_items(base_item)
end

# Add a couple unique items based on random base items named after the sc_bank
# so it will be clear if they are showing up where they aren't supposed to be
4.times do |index|
  seed_random_item_with_name(sc_org, "Second City Item ##{index + 1}")
end

# Keep a list of these unique items so its easy to use them for later records
sc_org_unique_items = sc_org.items.where("name ilike ?", "%Second City Item #%")

# Assign a value to some organization items to verify totals are working
Organization.all.find_each do |org|
  org.items.where(value_in_cents: 0).limit(10).each do |item|
    item.update(value_in_cents: 100)
  end
end

# ----------------------------------------------------------------------------
# Request Units
# ----------------------------------------------------------------------------

complete_orgs.each do |org|
  %w[pack box flat].each do |name|
    Unit.create!(organization: org, name: name)
  end

  org.items.each_with_index do |item, i|
    if item.name == "Pads"
      %w[box pack].each { |name| item.request_units.create!(name: name) }
    elsif item.name == "Wipes (Baby)"
      item.request_units.create!(name: "pack")
    elsif item.name == "Kids Pull-Ups (5T-6T)"
      %w[pack flat].each do |name|
        item.request_units.create!(name: name)
      end
    end
  end
end

# ----------------------------------------------------------------------------
# Item Categories
# ----------------------------------------------------------------------------

Organization.all.find_each do |org|
  ["One", "Two", "Three"].each do |letter|
    FactoryBot.create(:item_category, organization: org, name: "Category #{letter}")
  end
end

# ----------------------------------------------------------------------------
# Item <-> ItemCategory
# ----------------------------------------------------------------------------

Organization.all.find_each do |org|
  # Added `nil` to randomly choose to not categorize items sometimes via sample
  item_category_ids = org.item_categories.map(&:id) + [nil]

  org.items.each do |item|
    item.update(item_category_id: item_category_ids.sample)
  end
end

# ----------------------------------------------------------------------------
# Partner Group & Item Categories
# ----------------------------------------------------------------------------
Organization.all.find_each do |org|
  # Setup the Partner Group & their item categories
  partner_group_one = FactoryBot.create(:partner_group, organization: org)

  total_item_categories_to_add = Faker::Number.between(from: 1, to: 2)
  org.item_categories.sample(total_item_categories_to_add).each do |item_category|
    partner_group_one.item_categories << item_category
  end
  next unless org.name== pdx_org.name
  partner_group_two=FactoryBot.create(:partner_group, organization: org)
  org.item_categories.each do |item_category|
    partner_group_two.item_categories << item_category
  end
end

# ----------------------------------------------------------------------------
# Users
# ----------------------------------------------------------------------------

[
  {email: "superadmin@example.com", organization_admin: false, super_admin: true},
  {email: "org_admin1@example.com", organization_admin: true, organization: pdx_org},
  {email: "org_admin2@example.com", organization_admin: true, organization: sf_org},
  {email: "second_city_admin@example.com", organization_admin: true, organization: sc_org},
  {email: "user_1@example.com", organization_admin: false, organization: pdx_org},
  {email: "user_2@example.com", organization_admin: false, organization: sf_org},
  {email: "second_city_user@example.com", organization_admin: false, organization: sc_org},
  {email: "test@example.com", organization_admin: false, organization: pdx_org, super_admin: true},
  {email: "test2@example.com", organization_admin: true, organization: pdx_org}
].each do |user_data|
  user = User.create(
    email: user_data[:email],
    password: "password!",
    password_confirmation: "password!"
  )

  if user_data[:organization]
    user.add_role(:org_user, user_data[:organization])
  end

  if user_data[:organization_admin]
    user.add_role(:org_admin, user_data[:organization])
  end

  if user_data[:super_admin]
    user.add_role(:super_admin)
  end
end

# ----------------------------------------------------------------------------
# Donation Sites
# ----------------------------------------------------------------------------

complete_orgs.each do |org|
  [
    {name: "#{org.city} Hardware", address: "1234 SE Some Ave., #{org.city}, #{org.state} 12345"},
    {name: "#{org.city} Parks Department", address: "2345 NE Some St., #{org.city}, #{org.state} 12345"},
    {name: "Waffle House", address: "3456 Some Bay., #{org.city}, #{org.state} 12345"},
    {name: "Eagleton Country Club", address: "4567 Some Blvd., Eagleton, #{org.state} 12345"}
  ].each do |donation_option|
    DonationSite.find_or_create_by!(address: donation_option[:address]) do |donation|
      donation.name = donation_option[:name]
      donation.organization = org
    end
  end
end

# ----------------------------------------------------------------------------
# Partners & Associated Data
# ----------------------------------------------------------------------------

note = [
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent ac enim orci. Donec id consequat est. Vivamus luctus vel erat quis tincidunt. Nunc quis varius justo. Integer quam augue, dictum vitae bibendum in, fermentum quis felis. Nam euismod ultrices velit a tristique. Vestibulum sed tincidunt erat. Vestibulum et ullamcorper sem. Sed ante leo, molestie vitae augue ac, aliquam ultrices enim."
]

[
  {
    name: "Pawnee Parent Service",
    email: "verified@example.com",
    status: :approved,
    quota: 500,
    notes: note.sample
  },
  {
    name: "Pawnee Homeless Shelter",
    email: "invited@pawneehomeless.com",
    status: :invited,
    notes: note.sample
  },
  {
    name: "Pawnee Pregnancy Center",
    email: "unverified@pawneepregnancy.com",
    status: :invited,
    notes: note.sample
  },
  {
    name: "Pawnee Senior Citizens Center",
    email: "recertification_required@example.com",
    status: :recertification_required,
    notes: note.sample
  },
  {
    name: "Pawnee Middle School",
    email: "waiting@example.com",
    status: :awaiting_review,
    notes: note.sample
  },
  {
    name: "Second Street Community Outreach",
    status: :approved,
    email: "approved_2@example.com",
    notes: note.sample
  },
  {
    name: "Second City Senior Center",
    email: "second_city_senior_center@example.com",
    status: :approved,
    quota: 500,
    notes: note.sample,
    organization: sc_org
  }
].each do |partner_option|
  p = Partner.find_or_create_by!(partner_option) do |partner|
    partner.organization = if partner_option.key?(:organization)
      partner_option[:organization]
    else
      pdx_org
    end

    partner.partner_group = if partner_option[:name] == "Second Street Community Outreach"
      pdx_org.partner_groups.find_by(name: "Group 2")
    else
      partner.organization.partner_groups.first
    end
  end

  # Base profile information all partners should have
  # Includes fields in the agency_information, executive_director, and pick_up_person partial
  # The counties and areas served by the partner are handled elsewere
  profile = Partners::Profile.create!({
    essentials_bank_id: p.organization_id,
    partner_id: p.id,
    address1: Faker::Address.street_address,
    address2: Faker::Address.street_address,
    city: Faker::Address.city,
    executive_director_email: p.email,
    executive_director_name: Faker::Name.name,
    executive_director_phone: Faker::PhoneNumber.phone_number,
    pick_up_email: Faker::Internet.email,
    pick_up_name: Faker::Name.name,
    pick_up_phone: Faker::PhoneNumber.phone_number,
    primary_contact_email: Faker::Internet.email,
    primary_contact_mobile: Faker::PhoneNumber.phone_number,
    primary_contact_name: Faker::Name.name,
    primary_contact_phone: Faker::PhoneNumber.phone_number,
    state: Faker::Address.state_abbr,
    website: Faker::Internet.domain_name,
    zip_code: Faker::Address.zip,
    zips_served: Faker::Address.zip,
  })

  # Optional information that only established partners (ready for approval, approved or require_recertification)
  # would have
  # Also only add information that corresponds to the partner_form_fields the org has chosen
  if [ "awaiting_review", "approved", "recertification_required" ].include? p.status
    agency_type = Partners::Profile::agency_types.values.sample
    # The agency_information and partner_settings partials are always shown
    profile.update(
      agency_mission: Faker::Lorem.paragraph(sentence_count: 2),
      agency_type: agency_type,
      enable_child_based_requests: true,
      enable_individual_requests: true,
      enable_quantity_based_requests: true,
      name: p.name,
      other_agency_type: (agency_type == "OTHER") ? Faker::Lorem.word : nil,
      program_address1: Faker::Address.street_address,
      program_address2: Faker::Address.street_address,
      program_city: Faker::Address.city,
      program_state: Faker::Address.state_abbr,
      program_zip_code: Faker::Address.zip,
    )

    if p.partials_to_show.include? "media_information"
      profile.update(
        facebook: Faker::Internet.url(host: 'facebook.com'),
        instagram: Faker::Internet.url(host: 'instagram.com'),
        no_social_media_presence: false,
        twitter: Faker::Internet.url(host: 'twitter.com'),
      )
    end

    if p.partials_to_show.include? "agency_stability"
      founded_year = Faker::Date.between(from: 50.years.ago, to: Date.today).year
      profile.update(
        case_management: true,
        currently_provide_diapers: true,
        essentials_use: Faker::Lorem.paragraph(sentence_count: 2),
        evidence_based: true,
        form_990: true,
        founded: founded_year,
        program_age: Date.today.year - founded_year,
        program_description: Faker::Lorem.paragraph(sentence_count: 2),
        program_name: Faker::Company.name,
        receives_essentials_from_other: Faker::Lorem.sentence,
      )
    end
  
    if p.partials_to_show.include? "organizational_capacity"
      profile.update(
        client_capacity: Faker::Lorem.sentence,
        describe_storage_space: Faker::Lorem.paragraph(sentence_count: 2),
        storage_space: true,
      )
    end

    if p.partials_to_show.include? "sources_of_funding"
      profile.update(
        essentials_budget: Faker::Lorem.sentence,
        essentials_funding_source: Faker::Lorem.sentence,
        sources_of_diapers: Faker::Lorem.sentence,
        sources_of_funding: Faker::Lorem.sentence,
      )
    end

    if p.partials_to_show.include? "population_served"

      def calculate_array_of_percentages( num_entries )
        percentages = []
        remaining_percentage = 100
        share_ceiling = 100 / num_entries
        (num_entries - 1).times do
          percentage = Faker::Number.within(range: 1..share_ceiling)
          remaining_percentage -= percentage
          percentages.append( percentage )
        end
        percentages.append( remaining_percentage )
        return percentages
      end

      pop_percentages = calculate_array_of_percentages(8) # 8 population fields
      poverty_percentages = calculate_array_of_percentages(4) # 4 poverty fields

      profile.update(
        above_1_2_times_fpl: poverty_percentages[0],
        at_fpl_or_below: poverty_percentages[1],
        greater_2_times_fpl: poverty_percentages[2],
        income_requirement_desc: true,
        income_verification: true,
        population_american_indian: pop_percentages[0],
        population_asian: pop_percentages[1],
        population_black: pop_percentages[2],
        population_hispanic: pop_percentages[3],
        population_island: pop_percentages[4],
        population_multi_racial: pop_percentages[5],
        population_other: pop_percentages[6],
        population_white: pop_percentages[7],
        poverty_unknown: poverty_percentages[3],
        zips_served: Faker::Address.zip_code,
      )
    end

    if p.partials_to_show.include? "agency_distribution_information"
      profile.update(
        distribution_times: Faker::Lorem.sentence,
        more_docs_required: Faker::Lorem.sentence,
        new_client_times: Faker::Lorem.sentence,
      )
    end
  end

  user = ::User.create!(
    name: Faker::Name.name,
    password: "password!",
    password_confirmation: "password!",
    email: p.email,
    invitation_sent_at: Time.utc(2021, 9, 8, 12, 43, 4),
    last_sign_in_at: Time.utc(2021, 9, 9, 11, 34, 4)
  )

  user.add_role(:partner, p)

  user_2 = ::User.create!(
    name: Faker::Name.name,
    password: "password!",
    password_confirmation: "password!",
    email: Faker::Internet.email,
    invitation_sent_at: Time.utc(2021, 9, 16, 12, 43, 4),
    last_sign_in_at: Time.utc(2021, 9, 17, 11, 34, 4)
  )

  user_2.add_role(:partner, p)

  #
  # Skip creating records that they would have created after
  # they've accepted the invitation
  #
  next if p.status == "uninvited"

  families = (1..Faker::Number.within(range: 4..13)).to_a.map do
    Partners::Family.create!(
      guardian_first_name: Faker::Name.first_name,
      guardian_last_name: Faker::Name.last_name,
      guardian_zip_code: Faker::Address.zip_code,
      guardian_county: Faker::Address.community, # Faker doesn't have county, this has same flavor, and isn't country
      guardian_phone: Faker::PhoneNumber.phone_number,
      case_manager: Faker::Name.name,
      home_adult_count: [1, 2, 3].sample,
      home_child_count: [0, 1, 2, 3, 4, 5].sample,
      home_young_child_count: [1, 2, 3, 4].sample,
      sources_of_income: Partners::Family::INCOME_TYPES.sample(2),
      guardian_employed: Faker::Boolean.boolean,
      guardian_employment_type: Partners::Family::EMPLOYMENT_TYPES.sample,
      guardian_monthly_pay: [1, 2, 3, 4].sample,
      guardian_health_insurance: Partners::Family::INSURANCE_TYPES.sample,
      comments: Faker::Lorem.paragraph,
      military: false,
      partner: p
    )
  end

  requestable_items = PartnerFetchRequestableItemsService.new(partner_id: p.id).call.map(&:last)

  families.each do |family|
    Partners::AuthorizedFamilyMember.create!(
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      date_of_birth: Faker::Date.birthday(min_age: 18, max_age: 100),
      gender: Faker::Gender.binary_type,
      comments: Faker::Lorem.paragraph,
      family: family
    )

    family.home_child_count.times do
      Partners::Child.create!(
        family: family,
        first_name: Faker::Name.unique.first_name,
        last_name: family.guardian_last_name,
        date_of_birth: Faker::Date.birthday(min_age: 5, max_age: 18),
        gender: Faker::Gender.binary_type,
        child_lives_with: Partners::Child::CAN_LIVE_WITH.sample(2),
        race: Partners::Child::RACES.sample,
        agency_child_id: family.case_manager + family.guardian_last_name + family.guardian_first_name,
        health_insurance: family.guardian_health_insurance,
        comments: Faker::Lorem.paragraph,
        active: Faker::Boolean.boolean,
        archived: false,
        requested_item_ids: requestable_items.sample(rand(4))
      )
    end

    family.home_young_child_count.times do
      Partners::Child.create!(
        family: family,
        first_name: Faker::Name.unique.first_name,
        last_name: family.guardian_last_name,
        date_of_birth: Faker::Date.birthday(min_age: 0, max_age: 5),
        gender: Faker::Gender.binary_type,
        child_lives_with: Partners::Child::CAN_LIVE_WITH.sample(2),
        race: Partners::Child::RACES.sample,
        agency_child_id: family.case_manager + family.guardian_last_name + family.guardian_first_name,
        health_insurance: family.guardian_health_insurance,
        comments: Faker::Lorem.paragraph,
        active: Faker::Boolean.boolean,
        archived: false,
        requested_item_ids: requestable_items.sample(rand(4))
      )
    end
  end

  dates_generator = DispersedPastDatesGenerator.new

  Faker::Number.within(range: 32..56).times do |index|
    date = dates_generator.next

    partner_request = ::Request.new(
      partner_id: p.id,
      organization_id: p.organization_id,
      comments: Faker::Lorem.paragraph,
      partner_user_id: p.primary_user.id,
      created_at: date,
      updated_at: date
    )

    pads = p.organization.items.find_by(name: "Pads")
    new_item_request = Partners::ItemRequest.new(
      item_id: pads.id,
      quantity: Faker::Number.within(range: 10..30),
      children: [],
      name: pads.name,
      partner_key: pads.partner_key,
      created_at: date,
      updated_at: date,
      request_unit: "pack"
    )
    partner_request.item_requests << new_item_request

    items = p.organization.items.sample(Faker::Number.within(range: 4..14)) - [pads]

    partner_request.item_requests += items.map do |item|
      Partners::ItemRequest.new(
        item_id: item.id,
        quantity: Faker::Number.within(range: 10..30),
        children: [],
        name: item.name,
        partner_key: item.partner_key,
        created_at: date,
        updated_at: date
      )
    end

    partner_request.request_items = partner_request.item_requests.map do |ir|
      {
        item_id: ir.item_id,
        quantity: ir.quantity
      }
    end

    # Guarantee that there is a request for the items unique to the Second City Bank
    if (p.organization == sc_org) && (index < 4)
      unique_item = sc_org_unique_items[index]
      # Make sure we don't violate item request uniqueness if the unique_item was
      # randomly selected already
      if !partner_request.item_requests.any? { |item_request| item_request.item_id == unique_item.id }
        partner_request.item_requests << Partners::ItemRequest.new(
          item_id: unique_item.id,
          quantity: Faker::Number.within(range: 10..30),
          children: [],
          name: unique_item.name,
          partner_key: unique_item.partner_key,
          created_at: date,
          updated_at: date
        )
      end
    end

    partner_request.save!
  end
end

# ----------------------------------------------------------------------------
# Storage Locations
# ----------------------------------------------------------------------------

inv_arbor = StorageLocation.find_or_create_by!(name: "Bulk Storage Location") do |inventory|
  inventory.address = "Unknown"
  inventory.organization = pdx_org
  inventory.warehouse_type = StorageLocation::WAREHOUSE_TYPES[0]
  inventory.square_footage = 10_000
end
inv_pdxdb = StorageLocation.find_or_create_by!(name: "Pawnee Main Bank (Office)") do |inventory|
  inventory.address = "Unknown"
  inventory.organization = pdx_org
  inventory.warehouse_type = StorageLocation::WAREHOUSE_TYPES[1]
  inventory.square_footage = 20_000
end
StorageLocation.find_or_create_by!(name: "Second City Bulk Storage") do |inventory|
  inventory.address = "#{Faker::Address.street_address}, #{sc_org.city}, #{sc_org.state} #{sc_org.zipcode}"
  inventory.organization = sc_org
  inventory.warehouse_type = StorageLocation::WAREHOUSE_TYPES[0]
  inventory.square_footage = 10_000
end
StorageLocation.find_or_create_by!(name: "Second City Main Bank (Office)") do |inventory|
  inventory.address = "#{Faker::Address.street_address}, #{sc_org.city}, #{sc_org.state} #{sc_org.zipcode}"
  inventory.organization = sc_org
  inventory.warehouse_type = StorageLocation::WAREHOUSE_TYPES[1]
  inventory.square_footage = 20_000
end

inactive_storage = StorageLocation.find_or_create_by!(name: "Inactive Storage Location") do |inventory|
  inventory.address = "Unknown"
  inventory.organization = pdx_org
  inventory.warehouse_type = StorageLocation::WAREHOUSE_TYPES[2]
  inventory.square_footage = 5_000
end

inactive_storage.discard

#
# Define all the InventoryItem for each of the StorageLocation
#
StorageLocation.active.each do |sl|
  sl.organization.items.active.each do |item|
    InventoryItem.create!(
      storage_location: sl,
      item: item,
      quantity: Faker::Number.within(range: 500..2000)
    )
  end
end
Organization.all.find_each { |org| SnapshotEvent.publish(org) }

# Set minimum and recommended inventory levels for the complete organizations
# Only set inventory levels for the half of each org's items with the lowest stock
complete_orgs.each do |org|
  half_items_count = (org.items.count / 2).to_i
  low_items = org.items.left_joins(:inventory_items)
    .select("items.*, SUM(inventory_items.quantity) AS total_quantity")
    .group("items.id")
    .order("total_quantity")
    .limit(half_items_count).to_a

  min_qty = low_items.first.total_quantity
  max_qty = low_items.last.total_quantity

  # Ensure at least one of the items unique to the Second City Bank has minimum
  # and recommended quantities set
  if (org == sc_org) && !(low_items & sc_org_unique_items).any?
    low_items << sc_org_unique_items.last
  end

  low_items.each do |item|
    min_value = rand((min_qty / 10).floor..(max_qty / 10).ceil) * 10
    recommended_value = rand((min_value / 10).ceil..1000) * 10
    item.update(on_hand_minimum_quantity: min_value, on_hand_recommended_quantity: recommended_value)
  end
end

# Reload, since some of the items in sc_org_unique_items will have been altered
sc_org_unique_items.reload

complete_orgs.each do |org|
  # ----------------------------------------------------------------------------
  # Product Drives
  # ----------------------------------------------------------------------------

  [
    {name: "First Product Drive",
     start_date: 3.years.ago,
     end_date: 3.years.ago,
     organization: org},
    {name: "Best Product Drive",
     start_date: 3.weeks.ago,
     end_date: 2.weeks.ago,
     organization: org},
    {name: "Second Best Product Drive",
     start_date: 2.weeks.ago,
     end_date: 1.week.ago,
     organization: org}
  ].each { |product_drive| ProductDrive.find_or_create_by! product_drive }

  # ----------------------------------------------------------------------------
  # Product Drive Participants
  # ----------------------------------------------------------------------------

  [
    {business_name: "A Good Place to Collect Diapers",
     contact_name: "fred",
     email: "good@place.is",
     organization: org},
    {business_name: "A Mediocre Place to Collect Diapers",
     contact_name: "wilma",
     email: "ok@place.is",
     organization: org}
  ].each { |participant| ProductDriveParticipant.create! participant }

  # ----------------------------------------------------------------------------
  # Manufacturers
  # ----------------------------------------------------------------------------

  [
    {name: "Manufacturer 1", organization: org},
    {name: "Manufacturer 2", organization: org}
  ].each { |manu| Manufacturer.find_or_create_by! manu }
end

# ----------------------------------------------------------------------------
# Line Items
# ----------------------------------------------------------------------------

def seed_quantity(item_name, organization, storage_location, quantity)
  return if quantity.zero?

  item = Item.find_by(name: item_name, organization: organization)

  adjustment = organization.adjustments.create!(
    comment: "Starting inventory",
    storage_location: storage_location,
    user: User.with_role(:org_admin, organization).first
  )
  adjustment.line_items = [LineItem.new(quantity: quantity, item: item, itemizable: adjustment)]
  AdjustmentCreateService.new(adjustment).call
end

JSON.parse(Rails.root.join("db", "base_items.json").read).each do |_category, entries|
  entries.each do |entry|
    seed_quantity(entry["name"], pdx_org, inv_arbor, entry["qty"]["arbor"])
    seed_quantity(entry["name"], pdx_org, inv_pdxdb, entry["qty"]["pdxdb"])
  end
end

# ----------------------------------------------------------------------------
# Barcode Items
# ----------------------------------------------------------------------------

[
  {value: "10037867880046", name: "Kids (Size 5)", quantity: 108},
  {value: "10037867880053", name: "Kids (Size 6)", quantity: 92},
  {value: "10037867880039", name: "Kids (Size 4)", quantity: 124},
  {value: "803516626364", name: "Kids (Size 1)", quantity: 40},
  {value: "036000406535", name: "Kids (Size 1)", quantity: 44},
  {value: "037000863427", name: "Kids (Size 1)", quantity: 35},
  {value: "041260379000", name: "Kids (Size 3)", quantity: 160},
  {value: "074887711700", name: "Wipes (Baby)", quantity: 8},
  {value: "036000451306", name: "Kids Pull-Ups (4T-5T)", quantity: 56},
  {value: "037000862246", name: "Kids (Size 4)", quantity: 92},
  {value: "041260370236", name: "Kids (Size 4)", quantity: 68},
  {value: "036000407679", name: "Kids (Size 4)", quantity: 24},
  {value: "311917152226", name: "Kids (Size 4)", quantity: 82}
].each do |item|
  BarcodeItem.find_or_create_by!(value: item[:value]) do |barcode|
    barcode.item = pdx_org.items.find_by(name: item[:name])
    barcode.quantity = item[:quantity]
    barcode.organization = pdx_org
  end
end

# ----------------------------------------------------------------------------
# Kits
# ----------------------------------------------------------------------------

complete_orgs.each do |org|
  # Create comprehensive kits representing each NDBN category

  # Diaper Care Kit - covering multiple diaper categories
  diaper_kit_params = {
    name: "Diaper Care Kit",
    line_items_attributes: [
      {item_id: org.items.find_by(name: "Kids (Size 1)").id, quantity: 50},
      {item_id: org.items.find_by(name: "Kids (Size 2)").id, quantity: 50},
      {item_id: org.items.find_by(name: "Kids (Size 3)").id, quantity: 50},
      {item_id: org.items.find_by(name: "Wipes (Baby)").id, quantity: 10},
      {item_id: org.items.find_by(name: "Diaper Rash Cream/Powder").id, quantity: 2}
    ].compact_blank
  }

  if diaper_kit_params[:line_items_attributes].any?
    diaper_kit_service = KitCreateService.new(organization_id: org.id, kit_params: diaper_kit_params)
    diaper_kit_service.call
  end

  # Menstrual Care Kit
  menstrual_kit_params = {
    name: "Menstrual Care Kit",
    line_items_attributes: [
      {item_id: org.items.find_by(name: "Pads").id, quantity: 20},
      {item_id: org.items.find_by(name: "Tampons").id, quantity: 20},
      {item_id: org.items.find_by(name: "Liners (Menstrual)").id, quantity: 15}
    ].compact_blank
  }

  if menstrual_kit_params[:line_items_attributes].any?
    menstrual_kit_service = KitCreateService.new(organization_id: org.id, kit_params: menstrual_kit_params)
    menstrual_kit_service.call
  end

  # Adult Incontinence Kit
  adult_kit_params = {
    name: "Adult Incontinence Kit",
    line_items_attributes: [
      {item_id: org.items.find_by(name: "Adult Briefs (Large/X-Large)").id, quantity: 30},
      {item_id: org.items.find_by(name: "Adult Incontinence Pads").id, quantity: 25},
      {item_id: org.items.find_by(name: "Wipes (Adult)").id, quantity: 5},
      {item_id: org.items.find_by(name: "Underpads (Pack)").id, quantity: 5}
    ].compact_blank
  }

  if adult_kit_params[:line_items_attributes].any?
    adult_kit_service = KitCreateService.new(organization_id: org.id, kit_params: adult_kit_params)
    adult_kit_service.call
  end

  # Baby Care Essentials Kit - covering miscellaneous category
  baby_care_kit_params = {
    name: "Baby Care Essentials Kit",
    line_items_attributes: [
      {item_id: org.items.find_by(name: "Bibs (Adult & Child)").id, quantity: 5},
      {item_id: org.items.find_by(name: "Wipes (Baby)").id, quantity: 8},
      {item_id: org.items.find_by(name: "Diaper Rash Cream/Powder").id, quantity: 1},
      {item_id: org.items.find_by(name: "Cloth Diapers (Prefolds & Fitted)").id, quantity: 10}
    ].compact_blank
  }

  if baby_care_kit_params[:line_items_attributes].any?
    baby_care_service = KitCreateService.new(organization_id: org.id, kit_params: baby_care_kit_params)
    baby_care_service.call
  end

  # Training Kit - covering training pants category
  training_kit_params = {
    name: "Potty Training Kit",
    line_items_attributes: [
      {item_id: org.items.find_by(name: "Cloth Potty Training Pants/Underwear").id, quantity: 8},
      {item_id: org.items.find_by(name: "Kids Pull-Ups (2T-3T)").id, quantity: 20},
      {item_id: org.items.find_by(name: "Kids Pull-Ups (3T-4T)").id, quantity: 20},
      {item_id: org.items.find_by(name: "Wipes (Baby)").id, quantity: 5}
    ].compact_blank
  }

  if training_kit_params[:line_items_attributes].any?
    training_kit_service = KitCreateService.new(organization_id: org.id, kit_params: training_kit_params)
    training_kit_service.call
  end
end

# Create kit inventory for storage locations
complete_orgs.each do |org|
  org.storage_locations.active.each do |storage_location|
    org.kits.active.each do |kit|
      next unless kit.item # Ensure kit has an associated item

      # Create inventory for each kit
      InventoryItem.create!(
        storage_location: storage_location,
        item: kit.item,
        quantity: Faker::Number.within(range: 10..50)
      )
    end
  end
end

dates_generator = DispersedPastDatesGenerator.new
complete_orgs.each do |org|
  # ----------------------------------------------------------------------------
  # Donations
  # ----------------------------------------------------------------------------

  # Make some donations of all sorts
  20.times.each do |index|
    source = Donation::SOURCES.values.sample
    # Depending on which source it uses, additional data may need to be provided.
    donation = Donation.new(
      source: source,
      storage_location: org.storage_locations.active.sample,
      organization: org,
      issued_at: dates_generator.next
    )
    case source
    when Donation::SOURCES[:product_drive]
      donation.product_drive = org.product_drives.find_by(name: "Best Product Drive")
      donation.product_drive_participant = random_record_for_org(org, ProductDriveParticipant)
    when Donation::SOURCES[:donation_site]
      donation.donation_site = random_record_for_org(org, DonationSite)
    when Donation::SOURCES[:manufacturer]
      donation.manufacturer = random_record_for_org(org, Manufacturer)
    end

    rand(1..5).times.each do
      donation.line_items.push(LineItem.new(quantity: rand(250..500), item: random_record_for_org(org, Item)))
    end

    # Guarantee that there are at least a few donations for the items unique to the Second City Bank
    if (org == sc_org) && (index < 4)
      donation.line_items.push(LineItem.new(quantity: rand(250..500), item: sc_org_unique_items[index]))
    end

    DonationCreateService.call(donation)
  end

  # ----------------------------------------------------------------------------
  # Distributions
  # ----------------------------------------------------------------------------

  inventory = InventoryAggregate.inventory_for(org.id)
  # Make some distributions, but don't use up all the inventory
  20.times.each do |index|
    issued_at = dates_generator.next

    storage_location = org.storage_locations.active.sample
    stored_inventory_items_sample = inventory.storage_locations[storage_location.id].items.values.sample(20)
    delivery_method = Distribution.delivery_methods.keys.sample
    shipping_cost = (delivery_method == "shipped") ? rand(20.0..100.0).round(2).to_s : nil
    distribution = Distribution.new(
      storage_location: storage_location,
      partner: random_record_for_org(org, Partner),
      organization: org,
      issued_at: issued_at,
      created_at: 3.days.ago(issued_at),
      delivery_method: delivery_method,
      shipping_cost: shipping_cost,
      comment: "Urgent"
    )

    stored_inventory_items_sample.each do |stored_inventory_item|
      distribution_qty = rand(stored_inventory_item.quantity / 2)
      if distribution_qty >= 1
        distribution.line_items.push(LineItem.new(quantity: distribution_qty,
          item_id: stored_inventory_item.item_id))
      end
    end

    # Guarantee that there are at least a few distributions for the items unique to the Second City Bank
    if (org == sc_org) && (index < 4)
      unique_item_id = sc_org_unique_items[index].id
      distribution_qty = rand(storage_location.item_total(unique_item_id) / 2)
      distribution.line_items.push(
        LineItem.new(
          quantity: distribution_qty,
          item_id: unique_item_id
        )
      )
    end

    DistributionCreateService.new(distribution).call
  end

  # Create some distributions that use kits instead of individual items
  kit_items = org.items.joins(:kit).where(kits: {active: true})
  if kit_items.any?
    5.times do |index|
      issued_at = dates_generator.next
      storage_location = org.storage_locations.active.sample
      kit_item = kit_items.sample

      # Check if there's inventory for this kit
      kit_inventory_qty = storage_location.item_total(kit_item.id)
      next if kit_inventory_qty.zero?

      delivery_method = Distribution.delivery_methods.keys.sample
      shipping_cost = (delivery_method == "shipped") ? rand(20.0..100.0).round(2).to_s : nil

      kit_distribution = Distribution.new(
        storage_location: storage_location,
        partner: random_record_for_org(org, Partner),
        organization: org,
        issued_at: issued_at,
        created_at: 3.days.ago(issued_at),
        delivery_method: delivery_method,
        shipping_cost: shipping_cost,
        comment: "Kit distribution"
      )

      distribution_qty = [rand(1..3), kit_inventory_qty / 2].min
      if distribution_qty >= 1
        kit_distribution.line_items.push(
          LineItem.new(
            quantity: distribution_qty,
            item_id: kit_item.id
          )
        )

        DistributionCreateService.new(kit_distribution).call
      end
    end
  end
end

# ----------------------------------------------------------------------------
# Broadcast Announcements
# ----------------------------------------------------------------------------

BroadcastAnnouncement.create(
  user: User.find_by(email: "superadmin@example.com"),
  message: "This is the staging /demo server. There may be new features here! Stay tuned!",
  link: "https://example.com",
  expiry: Time.zone.today + 7.days,
  organization: nil
)

BroadcastAnnouncement.create(
  user: User.find_by(email: "org_admin1@example.com"),
  message: "This is the staging /demo server. There may be new features here! Stay tuned!",
  link: "https://example.com",
  expiry: Time.zone.today + 10.days,
  organization: pdx_org
)

# ----------------------------------------------------------------------------
# Vendors
# ----------------------------------------------------------------------------

# Create some Vendors so Purchases can have vendor_ids
complete_orgs.each do |org|
  Vendor.create(
    contact_name: Faker::FunnyName.two_word_name,
    email: Faker::Internet.email,
    phone: Faker::PhoneNumber.cell_phone,
    comment: Faker::Lorem.paragraph(sentence_count: 2),
    organization_id: org.id,
    address: "#{Faker::Address.street_address} #{Faker::Address.city}, #{Faker::Address.state_abbr} #{Faker::Address.zip_code}",
    business_name: Faker::Company.name,
    latitude: rand(-90.000000000...90.000000000),
    longitude: rand(-180.000000000...180.000000000),
    created_at: (Time.zone.today - rand(15).days),
    updated_at: (Time.zone.today - rand(15).days)
  )
end
3.times do
  Vendor.create(
    contact_name: Faker::FunnyName.two_word_name,
    email: Faker::Internet.email,
    phone: Faker::PhoneNumber.cell_phone,
    comment: Faker::Lorem.paragraph(sentence_count: 2),
    organization_id: Organization.all.pluck(:id).sample,
    address: "#{Faker::Address.street_address} #{Faker::Address.city}, #{Faker::Address.state_abbr} #{Faker::Address.zip_code}",
    business_name: Faker::Company.name,
    latitude: rand(-90.000000000...90.000000000),
    longitude: rand(-180.000000000...180.000000000),
    created_at: (Time.zone.today - rand(15).days),
    updated_at: (Time.zone.today - rand(15).days)
  )
end

# ----------------------------------------------------------------------------
# Purchases
# ----------------------------------------------------------------------------

suppliers = %w[Target Wegmans Walmart Walgreens]
amount_items = %w[period_supplies diapers adult_incontinence other]
comments = [
  "Maecenas ante lectus, vestibulum pellentesque arcu sed, eleifend lacinia elit. Cras accumsan varius nisl, a commodo ligula consequat nec. Aliquam tincidunt diam id placerat rutrum.",
  "Integer a molestie tortor. Duis pretium urna eget congue porta. Fusce aliquet dolor quis viverra volutpat.",
  "Nullam dictum ac lectus at scelerisque. Phasellus volutpat, sem at eleifend tristique, massa mi cursus dui, eget pharetra ligula arcu sit amet nunc."
]

dates_generator = DispersedPastDatesGenerator.new

complete_orgs.each do |org|
  25.times do |index|
    purchase_date = dates_generator.next
    storage_location = org.storage_locations.active.sample
    vendor = random_record_for_org(org, Vendor)
    purchase = Purchase.new(
      purchased_from: suppliers.sample,
      comment: comments.sample,
      organization_id: org.id,
      storage_location_id: storage_location.id,
      issued_at: purchase_date,
      created_at: purchase_date,
      updated_at: purchase_date,
      vendor_id: vendor.id,
      amount_spent_on_period_supplies_cents: rand(0..5_000),
      amount_spent_on_diapers_cents: rand(0..5_000),
      amount_spent_on_adult_incontinence_cents: rand(0..5_000),
      amount_spent_on_other_cents: rand(0..5_000)
    )

    purchase.amount_spent_in_cents = amount_items.map { |i| purchase.send(:"amount_spent_on_#{i}_cents") }.sum

    rand(1..5).times do
      purchase.line_items.push(
        LineItem.new(quantity: rand(1..1000),
          item_id: org.item_ids.sample)
      )
    end

    # Guarantee that there are at least a few purchases for the items unique to the Second City Bank
    if (org == sc_org) && (index < 4)
      purchase.line_items.push(
        LineItem.new(
          quantity: rand(1..1000),
          item_id: sc_org_unique_items[index].id
        )
      )
    end

    PurchaseCreateService.call(purchase)
  end
end

# ----------------------------------------------------------------------------
# Flipper
# ----------------------------------------------------------------------------

Flipper::Adapters::ActiveRecord::Feature.find_or_create_by(key: "new_logo")
Flipper::Adapters::ActiveRecord::Feature.find_or_create_by(key: "read_events")
Flipper.enable(:read_events)
Flipper::Adapters::ActiveRecord::Feature.find_or_create_by(key: "partner_step_form")
Flipper.enable(:partner_step_form)
Flipper::Adapters::ActiveRecord::Feature.find_or_create_by(key: "enable_packs")
Flipper.enable(:enable_packs)
# ----------------------------------------------------------------------------
# Account Requests
# ----------------------------------------------------------------------------
# Add some Account Requests to fill up the account requests admin page

[{organization_name: "Telluride Diaper Bank", website: "TDB.com", confirmed_at: nil},
  {organization_name: "Ouray Diaper Bank", website: "ODB.com", confirmed_at: nil},
  {organization_name: "Canon City Diaper Bank", website: "CCDB.com", confirmed_at: nil},
  {organization_name: "Golden Diaper Bank", website: "GDB.com", confirmed_at: (Time.zone.today - rand(15).days)},
  {organization_name: "Westminster Diaper Bank", website: "WDB.com", confirmed_at: (Time.zone.today - rand(15).days)},
  {organization_name: "Lakewood Diaper Bank", website: "LDB.com", confirmed_at: (Time.zone.today - rand(15).days)}].each do |account_request|
  AccountRequest.create(
    name: Faker::Name.unique.name,
    email: Faker::Internet.unique.email,
    organization_name: account_request[:organization_name],
    organization_website: account_request[:website],
    request_details: Faker::Lorem.paragraphs.join(", "),
    confirmed_at: account_request[:confirmed_at]
  )
end

# ----------------------------------------------------------------------------
# Questions
# ----------------------------------------------------------------------------

titles = [
  "Phasellus volutpat, sem at eleifend?",
  "ante lectus, vestibulum pellentesque arcu sed, eleifend lacinia elit?",
  "nisl, a commodo ligula consequat nec. Aliquam tincidunt diam id placerat rutrum?",
  "molestie tortor. Duis pretium urna eget congue?",
  "eleifend lacinia elit. Cras accumsan varius nisl, a commodo ligula consequat nec. Aliquam?"
]

answers = [
  "urna eget congue porta. Fusce aliquet dolor quis viverra volutpat. nisl, a commodo ligula consequat nec. Aliquam tincidunt diam id placerat rutrum.",
  "ger a molestie tortor. Duis pretium urna eget congue porta. Fusce aliquet dolor quis viv. nas ante lectus, vestibulum pellentesque arcu sed, eleifend lacinia elit. Cras accumsan varius nisl, a commodo ligula consequat nec",
  "que. Phasellus volutpat, sem at eleifend tristique, massa mi cursus dui, eget pharetra.",
  "olutpat, sem at eleifend tristique, massa mi cursus dui, eget pharetra ligula arcu sit amet nunc. aliquet dolor quis viverra volutpat. nisl, a commodo ligula consequat.",
  "Duis pretium urna eget congue porta. Fusce aliquet dolor quis viverra volutpat. Phasellus volutpat, sem at eleifend tristique, massa mi cursus dui, eget pharetra ligula arcu sit amet nunc."
]

5.times do
  Question.create(
    title: titles.sample,
    answer: answers.sample
  )
end

# ----------------------------------------------------------------------------
# Counties
# ----------------------------------------------------------------------------
Rake::Task["db:load_us_counties"].invoke

# ----------------------------------------------------------------------------
# Partner Counties
# ----------------------------------------------------------------------------

# aim -- every partner except one will have some non-zero number of counties,  and the first one 'verified' will have counties, for convenience sake
# Noted -- The first pass of this is kludgey as all get out.  I'm *sure* there is a better way
partner_ids = Partner.pluck(:id)
partner_ids.pop(1)
county_ids = County.pluck(:id)

partner_ids.each do |partner_id|
  partner = Partner.find(partner_id)
  profile = partner.profile
  num_counties_for_partner = Faker::Number.within(range: 1..10)
  remaining_percentage = 100
  share_ceiling = 100 / num_counties_for_partner  # arbitrary,  so I can do the math easily
  county_index = 0

  county_ids_for_this_partner = county_ids.sample(num_counties_for_partner)
  county_ids_for_this_partner.each do |county_id|
    client_share = if county_index == num_counties_for_partner - 1
      remaining_percentage
    else
      Faker::Number.within(range: 1..share_ceiling)
    end

    Partners::ServedArea.create(
      partner_profile: profile,
      county: County.find(county_id),
      client_share: client_share
    )
    county_index += 1
    remaining_percentage -= client_share
  end
end

# ----------------------------------------------------------------------------
# Transfers
# ----------------------------------------------------------------------------
from_id, to_id = pdx_org.storage_locations.active.limit(2).pluck(:id)
quantity = 5
inventory = View::Inventory.new(pdx_org.id)
# Ensure storage location has enough of item for transfer to succeed
item = inventory.items_for_location(from_id).find { _1.quantity > quantity }.db_item

transfer = Transfer.new(
  comment: Faker::Lorem.sentence,
  organization_id: pdx_org.id,
  from_id: from_id,
  to_id: to_id,
  line_items: [LineItem.new(quantity: quantity, item: item)]
)
TransferCreateService.call(transfer)

# ----------------------------------------------------------------------------
# Users invitation status
# ----------------------------------------------------------------------------
# Mark users `invitation_status` as `accepted`
#
# Addresses and resolves issue #4689, which can be found in:
# https://github.com/rubyforgood/human-essentials/issues/4689
User.where(invitation_token: nil).find_each do |user|
  user.update!(
    invitation_sent_at: Time.current,
    invitation_accepted_at: Time.current
  )
end

# Guarantee that at least one of the items unique to the Second City Bank has an
# inventory less than the recommended quantity.
item_to_make_scarce = sc_org_unique_items.where("on_hand_recommended_quantity > ?", 0).first
sc_org.storage_locations.each do |location|
  num_on_hand = location.item_total(item_to_make_scarce.id)
  if num_on_hand > item_to_make_scarce.on_hand_recommended_quantity
    num_to_remove = item_to_make_scarce.on_hand_recommended_quantity - 1 - num_on_hand
    adjustment = sc_org.adjustments.create!(
      comment: "Ensuring example of item below recommended inventory",
      storage_location: location,
      user: User.with_role(:org_admin, sc_org).first
    )
    adjustment.line_items = [LineItem.new(
      quantity: num_to_remove,
      item: item_to_make_scarce,
      itemizable: adjustment
    )]
    AdjustmentCreateService.new(adjustment).call
  end
end
