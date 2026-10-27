# pxt-microbit in Docker

**English** | [ภาษาไทย](README.th.md)

Run MakeCode for micro:bit ([microsoft/pxt-microbit](https://github.com/microsoft/pxt-microbit)) as a local server in Docker.

## Getting started

```bash
docker compose up -d --build
```

Then open **http://localhost:3232** on this machine, or **http://&lt;host IP&gt;:3232** (e.g. `http://192.168.1.10:3232`) on other computers on the same network.

- The first build takes several minutes (clone, `npm install`, `pxt buildtarget`, `pxt staticpkg` with the hex cache).
- By default the container serves the editor as a static site (`static` mode). No token is needed, it works from any machine on the network, and **Download** uses the bundled hex cache, so it works offline.
- Projects are saved in each user's browser. Use **Download** or **Export** to keep a copy.
- To find the host IP on Windows, run `ipconfig`. Allow port 3232 through the host firewall if other machines can't connect.

## Offline extensions

Add GitHub extension repos to [extensions.txt](extensions.txt), one per line, then rebuild:

```
microsoft/pxt-neopixel
microbit-foundation/pxt-microbit-v2-power
owner/repo#v1.2.3
```

```bash
docker compose up -d --build
```

During the build:
1. Each extension is cloned into `libs/`, along with the extensions it depends on (for example, neopixel depends on ws2812b).
2. The extensions are registered as bundled packages. They show up in the editor's **Extensions** dialog and work without GitHub access.
3. C++ code is compiled ahead of time through the cloud build and stored in `built/hexcache`, for each base project plus one extension.

Limitations:
- Building the image needs internet access. After that the editor works offline.
- TypeScript-only extensions work in any combination. For extensions with C++, the hex cache only covers adding **one** of them to a project. Using two or more C++ extensions together still needs the cloud build.
- Imported projects that reference an extension as `github:...` still try to load it from GitHub. Remove that extension and add the bundled one from the Extensions dialog instead.

## WebUSB (HTTPS)

Browsers allow WebUSB only on `https://` or `localhost`. So that other machines can flash a micro:bit straight from the browser, the container also serves HTTPS on port 3443 with a certificate it makes itself.

1. Set the host IP in `docker-compose.yml` (add a name too if you use one, comma separated), then start the container:

   ```yaml
   environment:
     PXT_TLS_HOSTS: "192.168.1.10"
   ```

   ```bash
   docker compose up -d
   ```

2. On each client machine, install the CA once: open **http://&lt;host IP&gt;:3232/rootCA.crt**, open the downloaded file, choose **Install Certificate**, and put it in "Trusted Root Certification Authorities". Or from a terminal (no admin needed):

   ```bash
   certutil -user -addstore Root rootCA.crt
   ```

3. Open **https://&lt;host IP&gt;:3443** in Chrome or Edge, plug in the micro:bit, choose **Connect device**, and **Download** then flashes the board directly. If the board isn't listed, update its DAPLink firmware.

How it works:
- On first start the container creates a local CA and keeps it in the `pxt-tls` volume. It then issues a server certificate for `localhost` and `PXT_TLS_HOSTS`, and reissues it when the hosts change or it is close to expiring.
- The CA can only sign private IPs (`10.x`, `172.16-31.x`, `192.168.x`, `127.x`) and names ending in `.local`, `.lan`, `.home.arpa` or `.internal`, so even if its key leaks it can't impersonate public websites. Other hosts in `PXT_TLS_HOSTS` are skipped with a warning.
- Only the public CA certificate is published. Its SHA-256 fingerprint is printed in `docker compose logs`, so you can compare it with the one shown when you install it.
- Changing the IP in `PXT_TLS_HOSTS` doesn't require reinstalling the CA. Deleting the volume (`docker compose down -v`) creates a new CA, which every client then has to install again.
- Reserve the host IP on the router (DHCP reservation) so it doesn't change.
- Allow port 3443 through the host firewall.
- To use your own certificate instead (e.g. from mkcert), mount a folder with `cert.pem` and `key.pem` at `/certs`, for example `- ./certs:/certs:ro` under `volumes`.

## Common commands

```bash
docker compose logs -f          # follow logs
docker compose down             # stop
docker compose build --no-cache # pull the latest source and rebuild
```

To pick a version, set `PXT_MICROBIT_REF` in `docker-compose.yml` to a branch or tag, such as `v9.1.1`.

## Entrypoint modes

| Command | Meaning |
|---|---|
| `static` (default) | serves the packaged editor (`built/packaged`) for every machine on the network |
| `serve` | `pxt serve --just`: the pxt dev server, saves projects to the `pxt-projects` volume (`/app/projects`). Hex cache works only from `localhost`, `127.0.0.1`, `192.168.x.x` or `*.local` opened once with `#local_token=offline` |
| `serve-full` | like `serve`, but rebuilds the target first |
| anything else | runs as is, e.g. `docker compose run --rm pxt-microbit pxt help` |

To use `serve`, add `command: serve` to the service in `docker-compose.yml`.

Environment variables: `PXT_PORT` (default 3232), `PXT_HTTPS_PORT` (3443, `static` only), `PXT_TLS_HOSTS` (empty: host IPs/names for the HTTPS certificate), `PXT_WSPORT` (3233, `serve` only), `PXT_LOCAL_TOKEN` (`offline`, `serve` only)

## Notes

- The server has no authentication. Share it on the local network only and don't expose the port to the internet.
- C++ (`.cpp`) builds that aren't in the hex cache use the MakeCode cloud build and need internet access.
- Flashing over WebUSB happens in the browser on your machine (Chrome/Edge). No USB passthrough into the container is needed.
- On other machines opened through `http://<host IP>:3232`, **Download** saves a `.hex` file: drag it onto the `MICROBIT` drive. Use the HTTPS address for WebUSB (see above).
