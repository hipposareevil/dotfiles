#!/bin/zsh

weather_file='current.weather'
stale_age=10

file=$(find ~/weather/ -mmin -${stale_age} -type file -name $weather_file)
echo ">$file<"
if [[ -f $file ]]; then
    # use cached weather
    echo "FROM FILE"
    weather=$(cat $file)
else
    # get new weather
    weather=$(~/weather/weather.py)
#    weather="new45.8°F"
    echo $weather > ~/weather/$weather_file
fi

echo ">$weather<"


