# セッションをデータベースに保存するように設定
Rails.application.config.session_store :active_record_store, key: '_shiritoruby_session'