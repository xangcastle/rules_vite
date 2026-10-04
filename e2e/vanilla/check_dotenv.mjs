// Asserts that vite_build with the default srcs read .env and
// .env.production: their VITE_* values must be inlined in the bundle.
import fs from "node:fs";
import path from "node:path";

const dist = process.argv[2];
const assets = path.join(dist, "assets");
const bundle = fs.readdirSync(assets)
    .filter((file) => file.endsWith(".js"))
    .map((file) => fs.readFileSync(path.join(assets, file), "utf8"))
    .join("\n");

const missing = ["greeting-from-dotenv", "stage-from-dotenv-production"]
    .filter((value) => !bundle.includes(value));
if (missing.length > 0) {
    console.error(`bundle in ${dist} lacks values from .env files: ${missing.join(", ")}`);
    process.exit(1);
}
console.log("bundle carries the .env and .env.production values");
