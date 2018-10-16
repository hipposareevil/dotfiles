#!/bin/zsh

weather_file='~/weather/current.weather'
stale_age=10


print -l $weather_file(mm+$stale_age) 2> /dev/null
echo "> $?"
