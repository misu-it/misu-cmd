#!/usr/bin/env ruby

require "thor"
require "open-uri"  
require "nokogiri"
require "openssl"

class MisuPrinter < Thor
  package_name "misu"

  desc "status", "Display printer status"
  def status name=""
    name == "" ? printers = ["fog", "mist", "dimma"] : printers = [name]
    domain = "misu.su.se"

    table_header = ["PRINTER", "BLACK", "CYAN", "MAGENTA", "YELLOW", "FUSER", "COLLECTOR"]
    table_items  = []

    printers.each do |printer|
      url = "https://#{printer}.#{domain}/"
      doc = Nokogiri::HTML(
        open(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
      )

      levels = []

      doc.css(".consumable").each_with_index do |consumable,index|
        consumable.css(".Attention").empty? ? status = "" : status = "(!)"
        levels << "#{consumable.css("#SupplyGauge#{index}")[0].children[0].text} #{status}"
      end

      collector_status = doc.css("#SupplyOtherStatus5").text

      table_items << [printer, levels[0], levels[1], levels[2], levels[3], levels[4], collector_status]
    end

    table_items.unshift table_header
    print_table table_items, colwidth: 8
  end

  desc "pagecollect", "Display printer usage"
  def pagecollect file
    data = File.open(file, 'rt') { |f| f.read }

    puts "Processing page log (#{data.each_line.count} pages)..."
    puts

    printers = {}
    users = {}
    log_started_at = ""
    log_ended_at = ""

    data.each_line.with_index do |line, index|
      printer_name = line.split.first
      user_name = line.split[1]
      index == 0 ? log_started_at = line.split[3][1..-1].split(":").first : "n/a"
      index == data.each_line.count-1 ? line.split[3][1..-1].split(":").first : "n/a"

      printers[printer_name].nil? ? printers[printer_name] = 1 : printers[printer_name] = printers[printer_name].to_i + 1
      users[user_name].nil? ? users[user_name] = 1 : users[user_name] = users[user_name].to_i + 1
    end

    printers = printers.sort_by {|k,v| v}.reverse
    users = users.sort_by {|k,v| v}.reverse

    puts "Printer usage #{log_started_at} - #{log_ended_at}"
    puts

    printer_header = ["PRINTER", "PAGES"]
    user_header = ["USER", "PAGES"]

    printers.unshift printer_header
    print_table printers, colwidth: 24

    puts

    users.unshift user_header
    print_table users, colwidth: 24
  end
end

MisuPrinter.start ARGV
