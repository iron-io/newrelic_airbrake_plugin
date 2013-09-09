# Twilio.com New Relic Agent

## What

This agent (extended from this [generic SaaS agent](https://github.com/newrelic-platform/ironworker_saas_agent))
runs on the [IronWorker](http://iron.io/worker) platform (another service by [Iron.io](http://iron.io)) and collects data from
Twilio.com to send to your own New Relic account.

## Why

Visualizing your Twilio.com data in New Relic is awesome!

## How

The following instructions describe how to configure and schedule this agent on IronWorker
to collect data and send it to New Relic. It's simple, fast, and **free**! (Note, please 
verify your account under the free plan to gain additional free compute hours per month.)

First, let's get our accounts set up: 

1. Create free account at [Iron.io](http://iron.io) if you don't already have one
1. Create free account at [New Relic](http://newrelic.com) if you don't already have one

Now the fun stuff:

### Start the Agent in a few seconds. No servers required!

Get started in a few seconds!

1. Go to: http://hud.iron.io/newrelic/twilio_agent
2. Fill in your New Relic license key and Twilio.com information
3. Click "Start Agent"

Boom, done!  It can take 5-10 minutes for data to show up in New Relic so be patient. 

### For unofficially supported agents 

You can use IronWorker's [Turnkey Workers](http://dev.iron.io/worker/turnkey) feature. 

1. Log in to https://hud.iron.io/worker/turnkey
1. Enter `https://github.com/iron-io/newrelic_twilio_plugin/blob/master/twilio_agent.worker` in the "Worker URL" field.
1. Complete the rest of the form and fill in the config
1. Click upload
1. Click queue to run it once to test it (check that data shows up in NewRelic)
1. Click schedule to schedule it

## For developers to modify or create your own agent 

If you want to fork and modify this agent or use it as a template to create your own agent for another service, follow
these instructions. 

1. Install the iron_worker_ng gem: `gem install iron_worker_ng`
1. Make a copy of twilio_agent.config.yml and call it `config.yml`. Fill it in with your credentials.
1. Upload the worker to IronWorker: `iron_worker upload --config config.yml twilio_agent --worker-config config.yml`
1. Test it: `iron_worker queue --config config.yml twilio_agent --wait` - can also check task status at http://hud.iron.io
1. Schedule it: `iron_worker schedule --config config.yml twilio_agent --run-every 60`

That's it! You will now see data in New Relic forever!
