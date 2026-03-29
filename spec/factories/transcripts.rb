FactoryBot.define do
  factory :transcript do
    meeting
    file_name { "notes.txt" }
    file_format { "txt" }
    language_code { "en" }
  end
end
