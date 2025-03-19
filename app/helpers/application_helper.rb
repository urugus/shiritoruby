module ApplicationHelper
  # 秒数を「○分○秒」形式にフォーマット
  def format_duration(seconds)
    return "-" if seconds.nil?

    minutes = seconds / 60
    remaining_seconds = seconds % 60

    if minutes > 0
      "#{minutes}分#{remaining_seconds}秒"
    else
      "#{remaining_seconds}秒"
    end
  end
end
