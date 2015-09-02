#!/bin/env ruby
require 'active_record'

ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'w'))

# establish database connection 
ActiveRecord::Base.establish_connection(
    :adapter  => 'sqlite3',
    :database => 'bus-schedule.db'
)

######################################################################
# Model

ActiveRecord::Schema.define do

    unless ActiveRecord::Base.connection.tables.include? 'bus_stops'
        create_table :bus_stops do |t|
            t.string :code,  null: false
        end
    end

    unless ActiveRecord::Base.connection.tables.include? 'routes'
        create_table :routes do |t|
            t.string :name,  null: false
            t.belongs_to :bus_line, index: true
        end
    end

    unless ActiveRecord::Base.connection.tables.include? 'bus_stops_routes'
        create_table :bus_stops_routes do |t|
            t.column "route_id", :integer, :null => false
            t.column "bus_stop_id",  :integer, :null => false
        end
    end

    unless ActiveRecord::Base.connection.tables.include? 'bus_lines'
        create_table :bus_lines do |t|
            t.column 'number', :integer, :null => false
            t.belongs_to :bus
        end
    end

    unless ActiveRecord::Base.connection.tables.include? 'schedules'
        create_table :schedules do |t|
            t.column 'arrival_time', :time, :null => false
            t.belongs_to :bus
        end
    end

    unless ActiveRecord::Base.connection.tables.include? 'buses'
        create_table :buses do |t|
            t.column 'schedule_id', :integer, :null => false
            t.column 'bus_line_id', :integer, :null => false
        end
    end

end

class BusStop < ActiveRecord::Base
    has_and_belongs_to_many :routes
end

class Route < ActiveRecord::Base
    has_and_belongs_to_many :bus_stops
    belongs_to :bus_line
end

class BusLine < ActiveRecord::Base
    has_many :routes
    has_many :buses
end

class Schedule < ActiveRecord::Base
    has_many :buses
end

class Bus < ActiveRecord::Base
    belongs_to :bus_line
    belongs_to :schedule
end

######################################################################
# Demonstration

# define 20 dummy bus stops
busStops = 1.upto(20).map { |i| BusStop.create(:code => "S%#02d" % i) }

puts "==================== 20 bus stops defined ===================="
puts BusStop.all.map { |s| s.code }.join(",")

# define 10 routes (5 pairs of forward and return routes)
routeGroups = 1.upto(5).map { |i| 
    # take 10 random bus stop for this route
    route_stops = busStops.shuffle.take(10)
    name = "Route %d" % i

    # forward route
    [ Route.create(:name => name, :bus_stops => route_stops),
    # return route
      Route.create(:name => "#{name} R", :bus_stops => route_stops.reverse)]
}

puts "==================== 10 routes defined ===================="
Route.all.each { |route|
    print route.name, " \t[", route.bus_stops.map { |s| s.code }.join(","), "]\n"
}
    
# define 5 bus lines
busLines = routeGroups.each_with_index.map { |routes, i|
    BusLine.create(:number => i, :routes => routes)
}

puts "==================== 5 bus lines defined ===================="
BusLine.all.each { |busLine|
    print "Line ", busLine.number, "\t\t[", busLine.routes.map { |r| r.name }.join(","), "]\n"
}

def print_all_buses()
    Bus.all.each { |bus| 
        print bus.schedule.arrival_time.strftime("%T"), "\tBus Line ", bus.bus_line.number ,"\n"
    }
end

# define 5 buses
schedule = Schedule.create(:arrival_time => Time.now)
buses = busLines.map { |busLine|
    Bus.create(:schedule => schedule, :bus_line => busLine)
}
puts "==================== 5 buses defined ===================="
print_all_buses

# add another 5 buses
schedule = Schedule.create(:arrival_time => (Time.now + 60 * 15))
busLines.each { |busLine|
    Bus.create(:schedule => schedule, :bus_line => busLine)
}
puts "==================== after add another 5 buses ===================="
print_all_buses

# delete all buses in line 4
Bus.all.select { |bus| bus.bus_line.number == 4 }.each { |bus| bus.destroy }
puts "==================== after delete buses in line 4 ===================="
print_all_buses

# reassign first bus to line 4
schedule = Schedule.all.last
busLine = BusLine.all.last
bus = Bus.all.first

bus.schedule = schedule
bus.bus_line = busLine
bus.save
puts "==================== after reassign bus to line 4 ===================="
print_all_buses


