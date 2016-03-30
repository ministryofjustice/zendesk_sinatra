## Synopsis
This was written to extract data from the zendesk api and strip out the required values

## Code Example
To access your chosen data you'll need to know the zendesk view_id
http://your_heroku_app/zendesk_view_id/piechart_data/satisfaction

## Installation
* Make sure you are logged in to heroku
* Get your zendesk API token and login email ready
* [![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/ministryofjustice/zendesk_sinatra/tree/master)
* When the steup is complete, select Manage App
* Switch to the Settings tab and click Reveal Config Vars
* Enter the following Key-Value pairs
    - zen_key: your zendesk email login
    - zen_token: your zendesk API token
* Done

## Contributors
1. Fork it ( https://github.com/ministryofjustice/zendesk_sinatra )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
