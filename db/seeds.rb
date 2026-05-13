CongregationImporter.call

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
