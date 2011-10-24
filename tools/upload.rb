#!/usr/bin/env ruby
require "fusion_tables"
require "csv"

username,password=File.readlines("#{ENV['HOME']}/.google-credentials").first.split(":") rescue raise "Enter your goog credentials in ~/.google-credentials as user:pass (#{$!})"

table_id=ARGV[0]
empty=ARGV.find{|x| x == "--empty"}
dry=ARGV.find{|x| x == "--dry"}

raise "use #{$0} table_id" if not table_id

# Connect to service    
@ft = GData::Client::FusionTables.new      
@ft.clientlogin(username, password)

@ft.execute("DELETE FROM #{table_id}") if empty and not dry
columns = nil
columns_sql = nil
sql = ''
CSV($stdin,:headers => true)     { |csv_in|  
  csv_in.each { |row|
    if not columns
      columns = csv_in.headers
      columns_sql = columns.map{|i| "'#{i.gsub("'","\\'")}'"}.join(",")
    end
    values_sql = columns.map{|column| "'#{row[column].gsub("'","\\'")}'"}.join(",")
    sql << "INSERT INTO #{table_id} (#{columns_sql}) values (#{values_sql});"
    if sql.length > 100000
      puts sql
      @ft.execute(sql)
      sql=''
    end
  } 
}  # from $stdin
if sql.length > 0
  puts sql
  @ft.execute(sql)
end

