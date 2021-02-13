## Beholder

This is an automatic relayer for Pleroma. I will not be supporting Mastodon with this, as Mastodon does not have native relays. What it does is checks the public timeline routinely, and when it sees an instance new to it, it attempts to establish a relay with that instance automatically.

### Requirements

* Ruby 3.0.0
* An admin bearer token for an instance

### Setup

Just clone this Git repository anywhere you would like to run it. Install Ruby 3.0.0 or higher and edit `info.json`. There's an example `info.json.example` file. It looks like this:

```json
{
	"bearer_token":        "YOUR BEARER TOKEN",
	"instance":            "yourinstance.tld",
	"attempted_instances": ["someinstance.tld", "someotherinstance.tld"],
	"limit":               20,
	"last_id":             null
}
```
