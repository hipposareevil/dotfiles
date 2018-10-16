#!/bin/zsh

#!/bin/zsh

weather_file=/Users/sjackson/weather/current.weather
previous=$(cat $weather_file)

# get new weather
weather=$(/Users/sjackson/weather/weather.py -p )
if [ $? -ne 0 ]; then
    echo "use no -p"
    weather=$(/Users/sjackson/weather/weather.py)
fi

# only write out if good file
if [ $? -eq 0 ]; then
    echo $weather > $weather_file
fi


