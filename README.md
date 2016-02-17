## HelloPlug

### Requirements

This project runs on Elixir 1.2.2 (install with `brew install elixir`)

### Running
In the project root run the following:

```sh
# Install Dependencies
mix deps:get

# Start the REPL with the webapp already running
iex -S mix
```

In order to load changes to a file, save the file and run inside the REPL:
```
c "lib/filename.ex"
```

### deployment
The step has to be performed on the same architecture as the target machine:

```sh
mix release
```

Then copy the `rel/hello_plug/releases/<VERSION>/hello_plug.tar.gz` file to
the target server (no need for erlang there!) open it and run:

```sh
bin/hello_plug start
```

It's also required to configure the destination host to redirect port 80 to
the application port (4000). This is done with the following commands:

```sh
sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 4000
sudo iptables -t nat -I OUTPUT -p tcp -o lo --dport 80 -j REDIRECT --to-ports 4000
```
