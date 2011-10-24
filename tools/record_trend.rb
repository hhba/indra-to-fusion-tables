#!/usr/bin/env ruby
require "fusion_tables"
require "csv"
presidente_table_id = "1942060"
trend_table_id = "1932057"

username,password=File.readlines("#{ENV['HOME']}/.google-credentials").first.split(":") rescue raise "Enter your goog credentials in ~/.google-credentials as user:pass (#{$!})"
@ft = GData::Client::FusionTables.new      
@ft.clientlogin(username, password)
data = @ft.execute("SELECT 'fecha carga', 'lista', 'cod_agrupacion', SUM('votos_agrupacion') as votos from #{presidente_table_id} group by 'fecha carga','lista','cod_agrupacion' ")

last_date = data.first && data.first[:"fecha_carga"] 
sql = "SELECT COUNT() from #{trend_table_id} WHERE 'fecha_carga'='#{last_date}'" 
data_exists_for_curr_date = @ft.execute(sql)
if not data_exists_for_curr_date.empty?
  puts "there's already data for #{last_date}"
else
  total_votos = data.map{|agrupacion| agrupacion[:"votos"]}.map(&:to_i).reduce(&:+)
  data.each{|agrupacion|
    pct = (100 * agrupacion[:"votos"].to_f / total_votos.to_f ).round(2)
    sql = "INSERT INTO #{trend_table_id} ('fecha_carga', 'lista', 'cod_agrupacion', 'votos', 'votos_pct') values ('#{agrupacion[:"fecha_carga"]}', '#{agrupacion[:"lista"]}', '#{agrupacion[:"cod_agrupacion"]}', '#{agrupacion[:"votos"]}', '#{pct}' )"
    @ft.execute(sql)
  }
end
