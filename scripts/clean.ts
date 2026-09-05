import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ora from "ora";
import pc from "picocolors";

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
  const spinner = ora("Checking build directory...").start();

  if (await pathExists(buildDir)) {
    spinner.text = `Cleaning ${pc.cyan("build/")} directory...`;
    await fs.rm(buildDir, { recursive: true, force: true });
    spinner.succeed(pc.green("Build directory successfully cleaned."));
  } else {
    spinner.info(pc.dim("Build directory is already clean."));
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  await clean();
}
