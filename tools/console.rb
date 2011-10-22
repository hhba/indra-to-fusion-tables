#!/usr/bin/env ruby
require "fusion_tables"
require "csv"
require "irb"

username,password=File.readlines("#{ENV['HOME']}/.google-credentials").first.split(":") rescue raise "Enter your goog credentials in ~/.google-credentials as user:pass (#{$!})"
@ft = GData::Client::FusionTables.new      
@ft.clientlogin(username, password)
IRB.start
