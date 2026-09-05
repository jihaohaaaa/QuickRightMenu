import { execFile, spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import ora, { type Ora } from "ora";
import pc from "picocolors";

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");

const buildDir = path.join(root, "build");
const sourceAppPath = path.join(buildDir, "QuickRightMenu.app");
const targetAppPath = "/Applications/QuickRightMenu.app";
const targetExtPath = path.join(
  targetAppPath,
  "Contents",
  "PlugIns",
  "QuickRightMenu Extension.appex"
);
const extensionId = "com.liaowenbin.QuickRightMenu.Extension";

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function runCommand(
  command: string,
  args: string[],
  ignoreError = false
): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: "ignore" });
    child.on("error", (err) => {
      if (ignoreError) resolve();
      else reject(err);
    });
    child.on("close", (code) => {
      if (code === 0 || ignoreError) {
        resolve();
      } else {
        reject(
          new Error(
            `Command failed with exit code ${code}: ${command} ${args.join(" ")}`
          )
        );
      }
    });
  });
}

interface RunningProcess {
  pid: number;
  cmd: string;
}

async function getRunningAppProcesses(): Promise<RunningProcess[]> {
  try {
    const { stdout } = await execFileAsync("pgrep", ["-fl", "QuickRightMenu"]);
    return stdout
      .trim()
      .split("\n")
      .filter((line) => line.trim().length > 0)
      .map((line) => {
        const parts = line.trim().split(/\s+/, 2);
        const pid = parseInt(parts[0], 10);
        const cmd = line.substring(parts[0].length).trim();
        return { pid, cmd };
      })
      .filter(({ pid, cmd }) => {
        if (isNaN(pid) || pid === process.pid || pid === process.ppid) {
          return false;
        }
        const isAppBinary =
          cmd.includes("Contents/MacOS/QuickRightMenu") ||
          cmd.startsWith("QuickRightMenu");
        const isRunner =
          cmd.includes("node") ||
          cmd.includes("tsx") ||
          cmd.includes("pnpm") ||
          cmd.includes("npm");
        return isAppBinary && !isRunner;
      });
  } catch {
    return [];
  }
}

async function ensureProcessesStopped(spinner: Ora): Promise<void> {
  spinner.text = "Checking for active QuickRightMenu processes...";
  const initialProcesses = await getRunningAppProcesses();

  if (initialProcesses.length === 0) {
    spinner.succeed(pc.dim("No active QuickRightMenu instances detected."));
    return;
  }

  const pids = initialProcesses.map((p) => p.pid);
  spinner.text = `Closing running instances ${pc.yellow(`[PID: ${pids.join(", ")}]`)} gracefully...`;

  // 1. Tell main application to quit gracefully via AppleScript
  await runCommand(
    "osascript",
    ["-e", 'tell application "QuickRightMenu" to quit'],
    true
  );

  // 2. Send SIGTERM to detected processes
  for (const proc of initialProcesses) {
    try {
      process.kill(proc.pid, "SIGTERM");
    } catch {
      // Process may already have terminated
    }
  }

  // 3. Wait and poll until processes exit (up to 2000ms)
  const maxWaitMs = 2000;
  const intervalMs = 100;
  let elapsed = 0;
  let remaining = await getRunningAppProcesses();

  while (remaining.length > 0 && elapsed < maxWaitMs) {
    await sleep(intervalMs);
    elapsed += intervalMs;
    remaining = await getRunningAppProcesses();
  }

  // 4. Force kill remaining if any still lingered
  if (remaining.length > 0) {
    spinner.text = `Lingering processes after ${elapsed}ms, force terminating with SIGKILL...`;
    for (const proc of remaining) {
      try {
        process.kill(proc.pid, "SIGKILL");
      } catch {
        // Ignored
      }
    }
    await sleep(150);
  }

  const finalCheck = await getRunningAppProcesses();
  if (finalCheck.length === 0) {
    spinner.succeed(
      `${pc.green("Existing QuickRightMenu instances closed")} ${pc.dim(
        `[PID: ${pids.join(", ")}]`
      )}`
    );
  } else {
    spinner.warn(
      pc.yellow(`PID(s) ${finalCheck.map((p) => p.pid).join(", ")} could not be terminated.`)
    );
  }
}

export interface InstallOptions {
  launchAfterInstall?: boolean;
}

export async function installApp(options: InstallOptions = {}): Promise<void> {
  console.log(pc.bold(pc.cyan("\n=== Deploying QuickRightMenu to /Applications ===")));

  if (!(await pathExists(sourceAppPath))) {
    throw new Error(
      `Build product not found at ${sourceAppPath}. Please run 'pnpm run build' first.`
    );
  }

  const spinner = ora().start();

  // 1. Check and terminate running instances
  await ensureProcessesStopped(spinner);

  // 2. Overwrite /Applications/QuickRightMenu.app
  spinner.start(`Copying bundle to ${pc.cyan(targetAppPath)}...`);
  try {
    if (await pathExists(targetAppPath)) {
      await fs.rm(targetAppPath, { recursive: true, force: true });
    }
    await fs.cp(sourceAppPath, targetAppPath, { recursive: true });
    spinner.succeed(`Copied bundle to ${pc.cyan(targetAppPath)}`);
  } catch (err: unknown) {
    spinner.fail(`Failed copying bundle to ${targetAppPath}`);
    const errorMsg = err instanceof Error ? err.message : String(err);
    if (errorMsg.includes("EACCES") || errorMsg.includes("permission denied")) {
      throw new Error(
        `Permission denied copying to ${targetAppPath}. Please ensure you have write permissions or run with sudo.`
      );
    }
    throw err;
  }

  // 3. Register and enable FinderSync extension
  spinner.start("Registering Finder extension via pluginkit...");
  await runCommand("pluginkit", ["-a", targetExtPath]);
  await runCommand("pluginkit", ["-e", "use", "-i", extensionId]);
  spinner.succeed(`Registered & enabled extension ${pc.dim(`(${extensionId})`)}`);

  // 4. Restart Finder to load updated extension
  spinner.start("Reloading Finder...");
  await runCommand("killall", ["Finder"], true);
  spinner.succeed("Reloaded Finder workspace");

  console.log(
    pc.bold(pc.green(`\n✓ QuickRightMenu successfully installed to /Applications!`))
  );

  // 5. Launch application
  const shouldLaunch = options.launchAfterInstall !== false;
  if (shouldLaunch) {
    spinner.start(`Launching ${pc.cyan(targetAppPath)}...`);
    await runCommand("open", [targetAppPath]);
    spinner.succeed(`Launched application: ${pc.cyan(targetAppPath)}`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  const noLaunch = process.argv.includes("--no-launch");
  await installApp({ launchAfterInstall: !noLaunch });
}
