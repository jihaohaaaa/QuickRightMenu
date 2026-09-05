import { cac } from "cac";
import { execFile, spawn } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import ora, { type Ora } from "ora";
import pc from "picocolors";
import { installApp } from "./install.ts";
import { generateIcons } from "./make_icon.ts";

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");

const buildDir = path.join(root, "build");
const appDir = path.join(buildDir, "QuickRightMenu.app");
const extDir = path.join(
  appDir,
  "Contents",
  "PlugIns",
  "QuickRightMenu Extension.appex"
);
const moduleCacheDir = path.join(buildDir, "ModuleCache");
const resourcesDir = path.join(root, "Resources");
const icnsPath = path.join(resourcesDir, "AppIcon.icns");
const vscodePngPath = path.join(resourcesDir, "vscode.png");
const hashFilePath = path.join(buildDir, ".build-hash");

export interface BuildOptions {
  runAfterBuild?: boolean;
  forceIcon?: boolean;
  install?: boolean;
  force?: boolean;
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function runCommand(command: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: "ignore" });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
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

async function getFilesRecursively(dir: string): Promise<string[]> {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        return getFilesRecursively(fullPath);
      }
      return [fullPath];
    })
  );
  return files.flat();
}

async function computeSourceHash(): Promise<string> {
  const hash = createHash("sha256");
  const sources = await getFilesRecursively(path.join(root, "Sources"));
  const resources = await getFilesRecursively(path.join(root, "Resources"));
  const allFiles = [...sources, ...resources].sort();

  for (const file of allFiles) {
    if (file.endsWith(".DS_Store")) continue;
    const stat = await fs.stat(file);
    hash.update(path.relative(root, file));
    hash.update(String(stat.mtimeMs));
    hash.update(String(stat.size));
  }
  return hash.digest("hex");
}

async function prepareVSCodeIcon(spinner: Ora, force = false): Promise<void> {
  if (!force && (await pathExists(vscodePngPath))) {
    spinner.succeed(pc.dim("VS Code icon ready (cached)"));
    return;
  }

  spinner.text = "Locating system Visual Studio Code icon...";

  const candidateIcnsPaths = [
    "/Applications/Visual Studio Code.app/Contents/Resources/Code.icns",
    "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/Code.icns",
    path.join(
      process.env.HOME || "",
      "Applications/Visual Studio Code.app/Contents/Resources/Code.icns"
    ),
  ];

  let foundIcns: string | null = null;
  for (const candidate of candidateIcnsPaths) {
    if (await pathExists(candidate)) {
      foundIcns = candidate;
      break;
    }
  }

  if (!foundIcns) {
    try {
      const { stdout } = await execFileAsync("mdfind", [
        'kMDItemCFBundleIdentifier == "com.microsoft.VSCode"',
      ]);
      const appPath = stdout.trim().split("\n")[0];
      if (appPath) {
        const icnsInApp = path.join(appPath, "Contents", "Resources", "Code.icns");
        if (await pathExists(icnsInApp)) {
          foundIcns = icnsInApp;
        }
      }
    } catch {
      // Ignored
    }
  }

  if (foundIcns) {
    spinner.text = `Extracting official VS Code icon from system...`;
    try {
      await execFileAsync("sips", [
        "-s",
        "format",
        "png",
        foundIcns,
        "--out",
        vscodePngPath,
        "-z",
        "64",
        "64",
      ]);
      spinner.succeed(
        `${pc.green("Extracted official VS Code icon")} ${pc.dim(
          `(${path.relative(root, vscodePngPath)})`
        )}`
      );
      return;
    } catch {
      // Fall through to vector drawing
    }
  }

  // Fallback: draw official vector ribbon icon with canvas
  spinner.text = "Rendering vector VS Code ribbon icon fallback...";
  const { createCanvas } = await import("@napi-rs/canvas");
  const canvas = createCanvas(64, 64);
  const ctx = canvas.getContext("2d");

  // Dark blue back fold
  ctx.fillStyle = "#0e639c";
  ctx.beginPath();
  ctx.moveTo(48, 6);
  ctx.lineTo(15, 27);
  ctx.lineTo(15, 37);
  ctx.lineTo(48, 58);
  ctx.closePath();
  ctx.fill();

  // Vibrant blue right beak
  ctx.fillStyle = "#007acc";
  ctx.beginPath();
  ctx.moveTo(48, 58);
  ctx.lineTo(60, 48);
  ctx.lineTo(60, 16);
  ctx.lineTo(48, 6);
  ctx.closePath();
  ctx.fill();

  // Sky blue front overlap
  ctx.fillStyle = "#1f8ad2";
  ctx.beginPath();
  ctx.moveTo(48, 58);
  ctx.lineTo(15, 37);
  ctx.lineTo(60, 16);
  ctx.closePath();
  ctx.fill();

  const buf = await canvas.encode("png");
  await fs.writeFile(vscodePngPath, buf);
  spinner.succeed(
    `${pc.green("Generated vector VS Code icon fallback")} ${pc.dim(
      `(${path.relative(root, vscodePngPath)})`
    )}`
  );
}

export async function build(options: BuildOptions = {}): Promise<void> {
  const startTime = Date.now();
  console.log(pc.bold(pc.cyan("\n=== Building QuickRightMenu ===")));

  const spinner = ora().start();

  // 1. Icon generation check
  const iconExists = await pathExists(icnsPath);
  if (options.forceIcon || !iconExists) {
    spinner.text = "Creating app icon assets...";
    await generateIcons(spinner);
    spinner.succeed(pc.green("App icons ready"));
  } else {
    spinner.succeed(pc.dim("App icon found, skipping generation"));
  }

  // 1b. VS Code icon check & build-time extraction
  await prepareVSCodeIcon(spinner, options.forceIcon);

  // 2. Incremental cache check
  const currentHash = await computeSourceHash();
  const appExecutable = path.join(appDir, "Contents", "MacOS", "QuickRightMenu");
  const extExecutable = path.join(
    extDir,
    "Contents",
    "MacOS",
    "QuickRightMenu Extension"
  );

  let isCached = false;
  if (
    !options.force &&
    (await pathExists(appExecutable)) &&
    (await pathExists(extExecutable)) &&
    (await pathExists(hashFilePath))
  ) {
    try {
      const savedHash = (await fs.readFile(hashFilePath, "utf-8")).trim();
      if (savedHash === currentHash) {
        isCached = true;
      }
    } catch {
      isCached = false;
    }
  }

  if (isCached) {
    spinner.succeed(
      `${pc.green("Build up to date (cached)")} ${pc.dim(
        "(use --force to rebuild)"
      )}`
    );
  } else {
    // 3. Prepare build directories
    spinner.start("Preparing clean build directories...");
    await fs.rm(buildDir, { recursive: true, force: true });

    const dirsToCreate = [
      path.join(appDir, "Contents", "MacOS"),
      path.join(appDir, "Contents", "Resources"),
      path.join(appDir, "Contents", "PlugIns"),
      path.join(extDir, "Contents", "MacOS"),
      path.join(extDir, "Contents", "Resources"),
      moduleCacheDir,
    ];

    await Promise.all(
      dirsToCreate.map((dir) => fs.mkdir(dir, { recursive: true }))
    );
    spinner.succeed("Build directory structure initialized");

    // 4. Copy resources
    spinner.start("Copying plists and assets...");
    const copyTasks = [
      fs.copyFile(
        path.join(resourcesDir, "AppInfo.plist"),
        path.join(appDir, "Contents", "Info.plist")
      ),
      fs.copyFile(
        path.join(resourcesDir, "ExtensionInfo.plist"),
        path.join(extDir, "Contents", "Info.plist")
      ),
    ];

    if (await pathExists(icnsPath)) {
      copyTasks.push(
        fs.copyFile(
          icnsPath,
          path.join(appDir, "Contents", "Resources", "AppIcon.icns")
        )
      );
    }

    if (await pathExists(vscodePngPath)) {
      copyTasks.push(
        fs.copyFile(
          vscodePngPath,
          path.join(appDir, "Contents", "Resources", "vscode.png")
        ),
        fs.copyFile(
          vscodePngPath,
          path.join(extDir, "Contents", "Resources", "vscode.png")
        )
      );
    }

    await Promise.all(copyTasks);
    spinner.succeed("Plists and icon assets linked");

    // 5. Query macOS SDK
    spinner.start("Detecting macOS SDK and build target...");
    const { stdout: sdkOutput } = await execFileAsync("xcrun", [
      "--sdk",
      "macosx",
      "--show-sdk-path",
    ]);
    const sdkPath = sdkOutput.trim();
    const arch = process.arch === "arm64" ? "arm64" : "x86_64";
    const target = `${arch}-apple-macos27.0`;
    spinner.succeed(`SDK configured: ${pc.dim(target)}`);

    // 6. Compile Swift sources
    spinner.start(`Compiling main application (${pc.cyan("QuickRightMenu")})...`);
    await runCommand("swiftc", [
      "-sdk",
      sdkPath,
      "-target",
      target,
      "-O",
      path.join(root, "Sources", "App", "QuickRightMenuApp.swift"),
      path.join(root, "Sources", "App", "SettingsView.swift"),
      "-o",
      appExecutable,
    ]);
    spinner.succeed(`Compiled main application executable`);

    spinner.start(`Compiling Finder extension (${pc.cyan("QuickRightMenu Extension")})...`);
    await runCommand("swiftc", [
      "-sdk",
      sdkPath,
      "-target",
      target,
      "-O",
      path.join(root, "Sources", "FinderExtension", "main.swift"),
      path.join(root, "Sources", "FinderExtension", "FinderSync.swift"),
      "-o",
      extExecutable,
    ]);
    spinner.succeed(`Compiled FinderSync extension executable`);

    // PlistBuddy
    spinner.start("Configuring extension principal class...");
    await runCommand("/usr/libexec/PlistBuddy", [
      "-c",
      "Set :NSExtension:NSExtensionPrincipalClass FinderSync",
      path.join(extDir, "Contents", "Info.plist"),
    ]);
    spinner.succeed("Extension principal class configured");

    // 7. Code signing
    spinner.start("Signing bundle with entitlements...");
    await runCommand("codesign", [
      "--force",
      "--sign",
      "-",
      "--entitlements",
      path.join(resourcesDir, "Extension.entitlements"),
      extDir,
    ]);

    await runCommand("codesign", [
      "--force",
      "--sign",
      "-",
      "--entitlements",
      path.join(resourcesDir, "App.entitlements"),
      appDir,
    ]);
    spinner.succeed("Extension and App bundle signed");

    // Save build hash
    await fs.writeFile(hashFilePath, currentHash, "utf-8");
  }

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(
    pc.bold(
      pc.green(
        `\n✓ Build completed in ${pc.yellow(`${durationSec}s`)} → ${pc.cyan(
          appDir
        )}`
      )
    )
  );

  if (options.install) {
    await installApp();
  } else if (options.runAfterBuild) {
    spinner.start(`Launching application: ${pc.cyan(appDir)}...`);
    await runCommand("open", [appDir]);
    spinner.succeed(`Launched application: ${pc.cyan(appDir)}`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === __filename) {
  const cli = cac("quickrightmenu-build");

  cli
    .command("[action]", "Build QuickRightMenu application and extensions")
    .option("-f, --force", "Force full rebuild, ignoring build cache")
    .option("-i, --install", "Install to /Applications after successful build")
    .option("-r, --run", "Launch the application after build")
    .option("--force-icon", "Force regeneration of icon assets")
    .action(
      async (
        _action,
        flags: {
          force?: boolean;
          install?: boolean;
          run?: boolean;
          forceIcon?: boolean;
        }
      ) => {
        await build({
          force: flags.force,
          install: flags.install,
          runAfterBuild: flags.run,
          forceIcon: flags.forceIcon,
        });
      }
    );

  cli.help();
  cli.version("1.0.0");
  cli.parse();
}
