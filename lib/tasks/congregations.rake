namespace :congregations do
  desc "Import congregations from 資料/伝道会番号.csv"
  task import: :environment do
    imported_count = CongregationImporter.call
    puts "Imported #{imported_count} congregations from 資料/伝道会番号.csv"
  end
end
