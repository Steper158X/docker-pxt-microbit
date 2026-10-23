# pxt-microbit in Docker

**English** | [ภาษาไทย](README.th.md)

Run MakeCode for micro:bit ([microsoft/pxt-microbit](https://github.com/microsoft/pxt-microbit)) as a local server in Docker.

## Getting started

```bash
docker compose up -d --build
```

Then open **http://localhost:3232/#local_token=offline**. You only need the token once: the browser remembers it, and after that http://localhost:3232 is enough.

- The first build takes several minutes (clone, `npm install`, `pxt buildtarget`, hex cache).
- Open the token URL first. Without the token the editor doesn't use the local server, so it skips the offline hex cache and doesn't save projects to the server.
- Projects saved on the local server are kept in the `pxt-projects` volume (`/app/projects`).

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
- The hex cache is only used when the editor is opened through `localhost` with the token.
- Imported projects that reference an extension as `github:...` still try to load it from GitHub. Remove that extension and add the bundled one from the Extensions dialog instead.
- To skip the hex cache (faster build), set the build arg `PXT_OFFLINE_HEX=0`.

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
| `serve` (default) | `pxt serve --just`: serves the target built into the image, starts fast |
| `serve-full` | rebuilds the target before serving |
| anything else | runs as is, e.g. `docker compose run --rm pxt-microbit pxt help` |

Environment variables: `PXT_PORT` (default 3232), `PXT_WSPORT` (3233), `PXT_LOCAL_TOKEN` (`offline`)

## Notes

- The server runs with `--noauth`. Don't expose this port to the internet.
- C++ (`.cpp`) builds that aren't in the hex cache use the MakeCode cloud build and need internet access.
- Flashing over WebUSB happens in the browser on your machine (Chrome/Edge). No USB passthrough into the container is needed.
