FactoryBot.define do
  factory :word do
    sequence(:word) { |n| "ruby_word_#{n}" }
    category { Word.categories.keys.sample }
    description { "説明テキスト" }

    trait :method do
      word { "puts" }
      category { "method" }
      description { "標準出力に文字列を出力するメソッド" }
    end

    trait :class_or_module do
      word { "array" }
      category { "class_or_module" }
      description { "配列を表すRubyのクラス" }
    end

    trait :gem do
      word { "rails" }
      category { "gem" }
      description { "Webアプリケーションフレームワーク" }
    end

    trait :term do
      word { "ruby" }
      category { "term" }
      description { "プログラミング言語" }
    end

    trait :keyword do
      word { "def" }
      category { "keyword" }
      description { "メソッド定義のためのキーワード" }
    end
  end
end