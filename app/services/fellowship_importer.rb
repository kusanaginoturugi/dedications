require "csv"

class FellowshipImporter
  DEFAULT_CSV_PATH = Rails.root.join("資料", "伝道会番号.csv")

  def self.call(csv_path: DEFAULT_CSV_PATH)
    new(csv_path: csv_path).call
  end

  def initialize(csv_path: DEFAULT_CSV_PATH)
    @csv_path = Pathname(csv_path)
  end

  def call
    imported_count = 0

    CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
      next if row.to_h.values.all?(&:blank?)

      code, old_code, name = row.fields.first(3).map { |value| value.to_s.strip }
      next if code.blank? || name.blank?

      Fellowship.find_or_initialize_by(code: code).tap do |fellowship|
        fellowship.old_code = old_code.presence
        fellowship.name = name
        fellowship.save!
      end

      imported_count += 1
    end

    imported_count
  end

  private

  attr_reader :csv_path
end
