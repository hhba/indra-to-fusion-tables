#!/usr/bin/ruby
require "fusion_tables"
data_dir = ARGV[0] 
raise "Use #{$0} datadir" if not data_dir
upload = ARGV.find{|x| x == "--upload"}
empty = ARGV.find{|x| x == "--empty"}
require "json"
d=JSON.parse(File.read("../data/tablas.json"))
d["tablas"].each{|fn,table_id|
  path = data_dir + "/" + fn + ".csv" 
  raise "Missing #{path}" if not File.exists?(path)
}

username,password=File.readlines("#{ENV['HOME']}/.google-credentials").first.split(":") rescue raise "Enter your goog credentials in ~/.google-credentials as user:pass (#{$!})"

# Connect to service    
@ft = GData::Client::FusionTables.new      
@ft.clientlogin(username, password)

d["tablas"].each{|fn,table_id|
  if table_id.is_a?(Hash)
    table_id = table_id["id"]
  end
  if empty 
    puts "delete from #{table_id}"
    @ft.execute("DELETE FROM #{table_id}") 
  end
  if upload
      path = data_dir + "/" + fn + ".csv" 
      puts "uploading #{path} to #{table_id}"

      columns = nil
      columns_sql = nil
      sql = ''
      CSV(File.open(path),:headers => true)     { |csv_in|  
        csv_in.each { |row|
          if not columns
            columns = csv_in.headers
            columns_sql = columns.map{|i| "'#{i.gsub("'","\'")}'"}.join(",")
          end
          values_sql = columns.map{|column| "'#{row[column].gsub("'","\'")}'"}.join(",")
          sql << "INSERT INTO #{table_id} (#{columns_sql}) values (#{values_sql});"
          if sql.length > 100000
            #puts sql
            begin
              @ft.execute(sql)
            rescue
              puts sql
              raise
            end
            sql=''
          end
        } 
      }  # from $stdin
      if sql.length > 0
        #puts sql
        begin
          @ft.execute(sql)
        rescue 
          puts sql
          raise
        end
      end

  end
}
