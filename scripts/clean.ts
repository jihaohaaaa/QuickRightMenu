import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const buildDir = path.join(root, "build");

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

export async function clean(): Promise<void> {
  if (await pathExists(buildDir)) {
    console.log(`Removing build directory: ${buildDir}`);
    await fs.rm(buildDir, { recursive: true, force: true });
    console.log("Build directory removed.");
  } else {
    console.log("Build directory already clean.");
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  await clean();
}
