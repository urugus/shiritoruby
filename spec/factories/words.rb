FactoryBot.define do
  factory :word do
    sequence(:word) { |n| "ruby_word_#{n}" }
    description { "説明テキスト" }

    trait :method do
      word { "puts" }
      normalized_word { "puts" }
      description { "標準出力に文字列を出力するメソッド" }
    end
  end
end
