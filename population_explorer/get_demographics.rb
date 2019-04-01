require 'json'
require 'pp'

# map city name to geo_id
fname_to_geo_id = {}
File.readlines('city_points.csv').each do |line| 
    geo_id, fname, long_str, lat_str = line.split(',')
    fname_to_geo_id[fname] = geo_id
end

abort "missing csv outfile" if ARGV.length < 1 
def append_to_data_file(geo_id, data)
    f = File.open(ARGV[0], 'a')
    under_ten_pct = "%.2f" % data[:under_ten_pct]
    over_65_pct = "%.2f" % data[:over_65_pct]
    f.write(%Q({"geo_id":#{geo_id},"name":"#{data[:name]}","total_population":#{data[:total]},"under_10":#{data[:under_ten]},"under_10_pct":#{under_ten_pct},"over_65":#{data[:over_65]},"over_65_pct":#{over_65_pct}},\n))
    f.close
end

def age_categories(data)
    under_ten = ["0_4", "5_9"]
    over_65 = ["65_69", "70_74", "75_79", "80plus"]

    pyramid_hash = {}
    data.each {|p|
        pyramid_hash[p['AgeGroup']] = p
    }

    [under_ten.inject(0.0) {|sum, n| sum + pyramid_hash[n]['TotalPop'].to_f}.to_i,
        over_65.inject(0.0) {|sum, n| sum + pyramid_hash[n]['TotalPop'].to_f}.to_i
    ]   
end

# get region id's from PE
target_group_id = 11676
get_cities_curl = "curl 'https://www.populationexplorer.com/api/geodata/target-group/#{target_group_id}/' -H 'Accept: application/json, text/plain, */*' -H 'Referer: https://app.populationexplorer.com/index.html' -H 'Origin: https://app.populationexplorer.com' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36' -H 'Authorization: Token 8fc55696922a843bfdd5d7bca4b4af17daa502b6' --compressed"

cities_json_str = `#{get_cities_curl}`
cities_json = JSON.parse(cities_json_str)

cities = cities_json['geo_polygons']

f = File.open(ARGV[0], 'a')
f.write("[")
f.close

# get demographic data for each region
city_demo_data = {}
cities.each {|city| 
    demo_data_str = `curl 'https://www.populationexplorer.com/api/geodata/geopolygons/#{city['id']}/' -H 'Accept: application/json, text/plain, */*' -H 'Referer: https://app.populationexplorer.com/index.html' -H 'Origin: https://app.populationexplorer.com' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36' -H 'Authorization: Token 8fc55696922a843bfdd5d7bca4b4af17daa502b6' --compressed`
    demo_data = JSON.parse(demo_data_str)
    pop_total = demo_data['population_datas'][0]['sum'].to_i
    pop_under_ten, pop_over_65 = age_categories(demo_data['population_datas'][0]['Pyramids'])
    city_demo_data = {name: city['name'], total: pop_total, under_ten: pop_under_ten, over_65: pop_over_65, under_ten_pct: pop_under_ten.to_f/pop_total.to_f * 100.0, over_65_pct: pop_over_65.to_f/pop_total.to_f * 100.0}

    append_to_data_file(fname_to_geo_id[city['name']], city_demo_data)
}
f = File.open(ARGV[0], 'a')
f.write("]")
f.close
