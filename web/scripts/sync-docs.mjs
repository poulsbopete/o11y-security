/**
 * Copy ../docs into public/ and point the deck at the Next.js converse proxy.
 */
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const webRoot = join(__dirname, "..");
const docsDir = join(webRoot, "..", "docs");
const pubDir = join(webRoot, "public");

rmSync(pubDir, { recursive: true, force: true });
mkdirSync(pubDir, { recursive: true });
cpSync(docsDir, pubDir, { recursive: true });

function patchMeta(html, value) {
  return html.replace(
    /<meta\s+name="o11y-converse-url"\s+content="[^"]*"\s*\/>/,
    `<meta name="o11y-converse-url" content="${value}" />`
  );
}

for (const rel of ["index.html", "prompts/index.html"]) {
  const fp = join(pubDir, rel);
  let html = readFileSync(fp, "utf8");
  const next = patchMeta(html, "/api/converse");
  if (next === html) {
    throw new Error(`sync-docs: did not find o11y-converse-url meta in ${rel}`);
  }
  writeFileSync(fp, next);
}

console.log("sync-docs: copied docs → web/public and set o11y-converse-url=/api/converse");
