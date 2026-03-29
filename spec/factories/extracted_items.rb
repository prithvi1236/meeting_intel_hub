FactoryBot.define do
  factory :extracted_item do
    meeting
    item_type { "decision" }
    description { "Agreed to prioritize the MVP." }
    status { "open" }
  end
end
