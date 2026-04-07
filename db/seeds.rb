csv_path = Rails.root.join("伝道会番号.csv")

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

default_password = ENV.fetch("DEFAULT_PASSWORD", "password123")

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = default_password
  user.password_confirmation = default_password
end
