
target_group_id = 11676
post_curl_req = "'https://www.populationexplorer.com/api/geodata/geopolygons/single/' -H 'Accept: application/json, text/plain, */*' -H 'Referer: https://app.populationexplorer.com/index.html' -H 'Origin: https://app.populationexplorer.com' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36' -H 'Authorization: Token 8fc55696922a843bfdd5d7bca4b4af17daa502b6' -H 'Content-Type: application/json;charset=UTF-8' --compressed "

def km_per_degree_lat(lat)
    (90.0 - lat) * (111.0 / 90.0)
end

File.readlines('points.csv').each do |line| 
    geo_id, fname, long_str, lat_str = line.split(',')
    long = long_str.to_f
    lat = lat_str.to_f

    # 50 km / km per degree
    delta_lat = 50.0 / 110.0
    delta_long = 50.0 / km_per_degree_lat(lat)


    north = lat + delta_lat
    south = lat - delta_lat
    east = long + delta_lat
    west = long - delta_lat

    req_data = %Q({"name":"#{fname}","the_geom":"POLYGON((#{long} #{north},#{east} #{lat},#{long} #{south},#{west} #{lat},#{long} #{north}))","target_group":#{target_group_id}})
    
    curl_req = "curl #{post_curl_req} --data-binary '#{req_data}'"

    `#{curl_req}`
end
