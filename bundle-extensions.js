// Clone GitHub extensions listed in extensions.txt into libs/ and register them
// as bundled packages in pxtarget.json so the editor can use them offline.
// Usage: node bundle-extensions.js <extensions.txt> <target dir>
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const [listFile, targetDir] = process.argv.slice(2);
const libsDir = path.join(targetDir, "libs");
const targetJsonPath = path.join(targetDir, "pxtarget.json");
const target = JSON.parse(fs.readFileSync(targetJsonPath, "utf8"));
const targetVersion = JSON.parse(fs.readFileSync(path.join(targetDir, "package.json"), "utf8")).version;
const builtin = new Set(target.bundleddirs.map(d => path.basename(d)));

// "github:owner/repo#ref" or "owner/repo#ref" -> { repo, ref }
function parseRepo(spec) {
    const m = /^(?:github:)?([\w.-]+\/[\w.-]+?)(?:\.git)?(?:#(.+))?$/.exec(spec.trim());
    return m && { repo: m[1].toLowerCase(), ref: m[2] };
}

const queue = fs.readFileSync(listFile, "utf8")
    .split(/\r?\n/)
    .map(l => l.replace(/#\s.*$/, "").trim())
    .filter(l => l && !l.startsWith("#"))
    .map(parseRepo)
    .filter(Boolean);

const repoToName = {};
const added = [];
const tmpRoot = fs.mkdtempSync(path.join(require("os").tmpdir(), "pxt-ext-"));

while (queue.length) {
    const { repo, ref } = queue.shift();
    if (repoToName[repo]) continue;

    const tmp = path.join(tmpRoot, repo.replace("/", "__"));
    const args = ["clone", "--depth", "1"];
    if (ref) args.push("--branch", ref);
    args.push(`https://github.com/${repo}.git`, tmp);
    console.log(`fetching ${repo}${ref ? "#" + ref : ""}`);
    execFileSync("git", args, { stdio: "inherit" });

    const cfg = JSON.parse(fs.readFileSync(path.join(tmp, "pxt.json"), "utf8"));
    const name = cfg.name;
    if (builtin.has(name)) {
        console.log(`  skipping ${repo}: '${name}' is already built in`);
        repoToName[repo] = name;
        continue;
    }
    fs.rmSync(path.join(tmp, ".git"), { recursive: true, force: true });
    const dest = path.join(libsDir, name);
    fs.rmSync(dest, { recursive: true, force: true });
    fs.cpSync(tmp, dest, { recursive: true });
    repoToName[repo] = name;
    added.push(name);

    for (const v of Object.values(cfg.dependencies || {})) {
        const dep = typeof v === "string" && v.startsWith("github:") && parseRepo(v);
        if (dep) queue.push(dep);
    }
}

// Point dependencies at the local copies instead of GitHub
for (const name of added) {
    const cfgPath = path.join(libsDir, name, "pxt.json");
    const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
    const deps = {};
    for (const [k, v] of Object.entries(cfg.dependencies || {})) {
        const dep = typeof v === "string" && v.startsWith("github:") && parseRepo(v);
        const local = dep ? repoToName[dep.repo] : k;
        deps[local] = fs.existsSync(path.join(libsDir, local)) ? `file:../${local}` : v;
    }
    cfg.dependencies = deps;
    // tests are not needed in the bundle and may pull more GitHub packages
    delete cfg.testDependencies;
    delete cfg.testFiles;
    cfg.public = true;
    // without this pxt treats the package as an old project and applies
    // upgrade patches (e.g. auto-adding packages) that break buildtarget
    cfg.targetVersions = Object.assign({}, cfg.targetVersions, { target: targetVersion, targetId: target.id });
    fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 4));
    console.log(`bundled ${name}: ${JSON.stringify(deps)}`);
}

target.bundleddirs.push(...added.map(n => `libs/${n}`));
fs.writeFileSync(targetJsonPath, JSON.stringify(target, null, 4));
fs.rmSync(tmpRoot, { recursive: true, force: true });
