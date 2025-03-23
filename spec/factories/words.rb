FactoryBot.define do
  factory :word do
    sequence(:word) { |n| "ruby_word_#{n}" }
    sequence(:normalized_word) { |n| "ruby_word_#{n}" }
    word_type { "method" }
    description { "説明テキスト" }

    trait :method do
      word { "puts" }
      normalized_word { "puts" }
      description { "標準出力に文字列を出力するメソッド" }
      word_type { "method" }
    end

    trait :keyword do
      word_type { "keyword" }
    end

    trait :class do
      word_type { "class" }
    end

    trait :module do
      word_type { "module" }
    end

    trait :gem do
      word_type { "gem" }
    end
  end
end
