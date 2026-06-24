import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const distDir = join(scriptDir, "..", "dist");
const indexPath = join(distDir, "index.html");

let html = await readFile(indexPath, "utf8");

const cssLinks = [...html.matchAll(/<link\s+rel="stylesheet"[^>]*href="([^"]+)"[^>]*>/g)];
for (const match of cssLinks) {
  const cssPath = join(distDir, match[1].replace(/^\.\//, ""));
  const css = (await readFile(cssPath, "utf8")).replace(/<\/style/gi, "<\\/style");
  html = html.replace(match[0], () => `<style>\n${css}\n</style>`);
}

const moduleScripts = [...html.matchAll(/<script\s+type="module"[^>]*src="([^"]+)"[^>]*><\/script>/g)];
const inlineScripts = [];
for (const match of moduleScripts) {
  const jsPath = join(distDir, match[1].replace(/^\.\//, ""));
  const js = (await readFile(jsPath, "utf8")).replace(/<\/script/gi, "<\\/script");
  inlineScripts.push(`<script>\n${js}\n</script>`);
  html = html.replace(match[0], () => "");
}

if (inlineScripts.length > 0) {
  html = html.replace("</body>", () => `${inlineScripts.join("\n")}\n  </body>`);
}

await writeFile(indexPath, html);
