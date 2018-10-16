## A Short Story
My zsh prompt starts with a cute cloud. 
I have nothing against clouds. I like clouds...
But this one was a little bit useless.
So I said to myself: Myself, Why don't you put the current weather condition in your prompt?
And that's how this happened.

## Notes 
Go to http://www.wunderground.com/weather/api/ to get your API key (Its free for <=500 queries in a day)
Set APIKEY env varible to the API Key you've obtained.

export APIKEY="myapikey"

The script connects to wunderground and asks for the weather for a particular zipcode.

Personaly I have cron job running every 1/2 h storing the weather into my $WEATHER env var...
But you could do something useful in many other ways.

The code is the documentation ;)
