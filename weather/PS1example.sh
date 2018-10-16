TERM=xterm-256color

export APIKEY="509241ad3549ec38"

now()
{
	date +%s
}

weather_color()
{
    weather_file=~/.weather

    if (egrep -q '.' ${weather_file}); 
    then
        temp=$(cut -d. -f1 ~/.weather | awk '{ print $NF}')
        
        [ ${temp} -gt 89 ] && color="\033[1;31m"
        [ ${temp} -gt 60 ] && [ ${temp} -lt 88 ] && color="\033[1;39m"
        [ ${temp} -lt 55 ] && color="\033[1;36m"
        echo -ne "${color}"
    fi
}

weather()
{
    poll_every=3600
    cliww="~/weather/weather.py -f -c"
    if ! [ -e ~/.weather ]; 
    then
        ${cliww} > ~/.weather
    else
	    last_run=$(stat -f %c ~/.weather)
    fi

	if [ $(( $last_run + $poll_every )) -lt $(now) ]; 
    then
        res=$(${cliww})
        if [ $? -eq 0 ]; 
        then
            echo ${res} > ~/.weather
        fi
	fi

    weather_color
    cat ~/.weather
}

_update_ps1()
{ 
    # This addon works quite nice if you're using something like powerline.
    export PS1="$(echo "$(weather)" && ~/powerline-bash/powerline-bash.py $?)"
}

export PROMPT_COMMAND="_update_ps1"
