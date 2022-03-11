## ExNews API

Lists the HN's current top 50 stories based on score.

- Created by: Rafael Antunes.
## How to run the application

- `mix deps.get`
- `iex -S mix`
- The application will listen to port `3000` and will serve `/posts/` `/post/` `/ws` endpoints.

## How it works

At start, the application will fetch the current top 50 stories by requesting it to the HN's API,
it will also keep creating a 5 minute timer and update the stories list based on it. 

The stories are avaliable via two public APIs:
- JSON over http 
- JSON over WebSockets

The WebSocket API is automatically updated when the stories list is refreshed.

