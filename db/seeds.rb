csv_path = Rails.root.join("資料", "伝道会番号.csv")

File.foreach(csv_path).with_index do |line, index|
  next if index.zero?

  normalized_line = line.delete_prefix("\uFEFF").strip
  next if normalized_line.blank?

  code, old_code, name = normalized_line.split(",", 3)

  Congregation.find_or_initialize_by(code: code).tap do |congregation|
    congregation.old_code = old_code
    congregation.name = name
    congregation.save!
  end
end

event31 = Event.find_or_create_by!(name: "第31回") do |event|
  event.is_active = true
end

# 既存の全申込を第31回に紐付ける（すでにある場合）
Order.where(event_id: nil).update_all(event_id: event31.id)

default_password = ENV.fetch("DEFAULT_PASSWORD", "password123")

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.name = "管理者"
  user.is_admin = true
  user.password = default_password
  user.password_confirmation = default_password
end
