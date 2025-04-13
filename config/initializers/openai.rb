# OpenAI API設定
# 環境変数OPENAI_API_KEYが設定されている場合のみ初期化
if Rails.env.production? && ENV["OPENAI_API_KEY"].present?
  begin
    require "openai"

    OpenAI.configure do |config|
      config.access_token = ENV["OPENAI_API_KEY"]
      config.organization_id = ENV["OPENAI_ORGANIZATION_ID"] if ENV["OPENAI_ORGANIZATION_ID"].present?

      # タイムアウト設定
      config.request_timeout = ENV.fetch("OPENAI_TIMEOUT", 10).to_i

      # リトライ設定
      config.max_retries = ENV.fetch("OPENAI_MAX_RETRIES", 2).to_i
    end

    Rails.logger.info "OpenAI API設定が完了しました"
  rescue LoadError => e
    Rails.logger.warn "OpenAI gemがインストールされていません: #{e.message}"
    Rails.logger.warn "bundle exec gem install ruby-openai を実行してください"
  rescue => e
    Rails.logger.error "OpenAI API設定エラー: #{e.message}"
  end
else
  Rails.logger.debug "OpenAI API設定をスキップしました（環境変数が設定されていないか、開発/テスト環境です）"
end
