# 14 — Xdebug and Debugging

Xdebug is a PHP extension that lets you step through your code, set breakpoints, and inspect variables — essential for serious debugging. KTStack makes enabling Xdebug simple and provides guidance for configuring your editor.

## What is Xdebug?

Xdebug is a PHP debugger that runs on your Mac alongside your PHP code. When enabled:
- You can set **breakpoints** in your code (stop execution at a line)
- You can **step through** code line by line
- You can **inspect variables** to see their values
- You can **watch expressions** as they change
- You get a **call stack** showing which function called which

Most modern editors (VS Code, PhpStorm, etc.) support Xdebug via the [DAP](https://microsoft.github.io/debug-adapter-protocol/) (Debug Adapter Protocol).

## Enabling Xdebug for a PHP version

1. Open KTStack and go to the **Runtimes** section (or **Settings > PHP Versions**).
2. Find the PHP version you want to debug (e.g., PHP 8.3).
3. Look for the **Xdebug** toggle or section.
4. If Xdebug is **not supported** for that version, you'll see a note — skip to troubleshooting.
5. Click the toggle to **enable Xdebug**.
6. KTStack downloads the Xdebug extension (if needed) and restarts PHP for that version.

While restarting, you may see a brief loading indicator. The toggle becomes **on** (green) once done.

![Xdebug toggle in Runtimes section](images/14-xdebug-enable-toggle.png)

### What happens when you enable Xdebug?

KTStack:
1. Downloads the Xdebug shared object (`.so` file) if not already installed
2. Creates a configuration file (`xdebug.ini`) in the PHP extension directory
3. Restarts the PHP-FPM process for that version
4. Sites on that PHP version blip briefly (requests may fail for a few seconds)

Once done, Xdebug listens on **port 9003** for connections from your editor.

## Configuring your editor: VS Code

To debug PHP in VS Code, you need the [PHP Debug](https://marketplace.visualstudio.com/items?itemName=felixbecker.php-debug) extension by Felix Becker.

### Step 1: Install the extension

1. Open VS Code and go to **Extensions** (Cmd+Shift+X).
2. Search for "PHP Debug" by Felix Becker.
3. Click **Install**.
4. Reload VS Code if prompted.

### Step 2: Configure the debugger

1. Open your project folder in VS Code.
2. Go to **Run and Debug** (Cmd+Shift+D) in the sidebar, or click the debug icon.
3. Click **"Create a launch.json file"** or **"Add Configuration..."**.
4. Choose **PHP** from the environment list (or manually edit `.vscode/launch.json`).

Paste or edit the configuration to look like this:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Listen for Xdebug",
            "type": "php",
            "request": "launch",
            "port": 9003,
            "xdebugSettings": {
                "max_data": 65535,
                "show_hidden": 1
            },
            "pathMapping": {
                "/var/www/html": "${workspaceFolder}"
            }
        }
    ]
}
```

**Key fields to customize:**

- **`"port"`**: Should be `9003` (the port Xdebug uses). Change it only if you have a conflict.
- **`"pathMapping"`**: Maps the path inside PHP to your local folder. Replace `/var/www/html` with your site's actual path on your Mac (e.g., `/Users/yourname/dev/myapp`). Replace `${workspaceFolder}` if your code is in a subfolder.

### Step 3: Set breakpoints and start debugging

1. In VS Code, open a PHP file from your project.
2. Click on a line number to set a **breakpoint** (a red dot appears).
3. Go to **Run and Debug** and click the **play icon** (or press F5) to start listening.
4. You'll see a message: "Listening for Xdebug on port 9003".
5. In your browser, open your site (e.g., `https://myapp.test/`) and trigger the code with the breakpoint.
6. VS Code pauses execution and shows the debugger panel with:
   - **Call Stack** — which functions led here
   - **Variables** — local variables and their values
   - **Watch** — expressions you're tracking
7. Use the debug toolbar to:
   - **Step Over** (F10) — run the next line
   - **Step Into** (F11) — enter a function
   - **Step Out** (Shift+F11) — exit the current function
   - **Continue** (F5) — resume until the next breakpoint

### Example configuration for a Laravel project

If your Laravel project is at `/Users/yourname/dev/myapp`:

```json
{
    "name": "Listen for Xdebug",
    "type": "php",
    "request": "launch",
    "port": 9003,
    "pathMapping": {
        "/Users/yourname/Library/Application Support/KTStack/sites/myapp": "/Users/yourname/dev/myapp"
    }
}
```

The first path is where KTStack serves the site from. The second is your actual project folder.

## Configuring other editors

### PhpStorm / JetBrains IDEs

PhpStorm has built-in Xdebug support:

1. Go to **PhpStorm > Preferences > Languages & Frameworks > PHP > Debug**.
2. Set **Xdebug port** to `9003`.
3. Go to **Run > Start Listening for PHP Debug Connections** (Cmd+Alt+Y).
4. Set a breakpoint in your code.
5. Trigger a request to your site and PhpStorm pauses execution.

### Sublime Text

Use the [Xdebug Client](https://packagecontrol.io/packages/Xdebug%20Client) package:

1. Install via Package Control: Cmd+Shift+P, type "Install Package", search "Xdebug Client".
2. Go to **Tools > Xdebug > Start Debugging Session** (or listen for incoming connections).
3. Set breakpoints by clicking the gutter.
4. Trigger requests and the debugger pauses.

## How debugging works

When you open a page in your browser:

1. **Xdebug starts a session** — the PHP process detects Xdebug is enabled and tries to connect to your editor
2. **Your editor listens** — VS Code (or PhpStorm) is listening on port 9003 for this connection
3. **Connection established** — Xdebug sends debugging info to your editor over the network
4. **Breakpoint hit** — if your code reaches a breakpoint, execution pauses
5. **You inspect** — you can see variables, step through lines, and watch expressions
6. **Resume or step** — you control what happens next

The connection is **local** (port 9003 is only available on your Mac), so it's safe.

## Tips and notes

- **Xdebug slows PHP down** — debugging adds overhead. Only enable it when you need it. Disable after debugging.
- **Only one debugger at a time** — if you have VS Code and PhpStorm both listening, only one will get the connection.
- **Breakpoint not hit?** Make sure the **pathMapping** in your editor config matches your actual file paths. If the paths don't match, the editor won't find the file and the breakpoint is ignored.
- **"Connection refused"** on startup? Make sure your editor is listening (in VS Code, press F5 first). Xdebug tries to connect as soon as the request starts, so your editor must be ready.
- **Port 9003 in use?** If another app is using port 9003, change the Xdebug port in your editor config to something else (e.g., 9004), then restart KTStack.
- **Debugging AJAX or API calls?** Use the same breakpoint approach — trigger the AJAX call from your browser or API Tester and the debugger pauses when the breakpoint is hit.
- **Long debugging sessions?** Xdebug timeouts if paused for too long (usually 5 minutes). Resume and try again.

## Common workflows

### Debugging a failing request

1. Enable Xdebug for the PHP version your site uses.
2. Open your project in VS Code.
3. Find the controller or function handling the request.
4. Set a breakpoint at the start of the logic.
5. Start listening (F5).
6. Visit the failing URL in your browser.
7. Step through the code and watch variables to find the bug.
8. Once fixed, toggle Xdebug off (or just close VS Code) to stop debugging.

### Debugging a command or scheduled task

Some frameworks like Laravel support debugging non-HTTP code. Set a breakpoint in your command, then run the command from the terminal while the debugger is listening — it should pause and let you step through.

### Inspecting database queries

Many ORMs log queries to variables you can inspect. Set a breakpoint after a query runs and look at the `$query` or `$sql` variable in the Variables panel.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Breakpoint never triggers | Check the **pathMapping** in your editor config. The file paths must match exactly. Restart the debugger (F5 in VS Code). |
| "Connection refused" when starting debugger | Make sure Xdebug is enabled in KTStack. Restart PHP-FPM in the Services section. Try toggling Xdebug off and on again. |
| Xdebug not available for my PHP version | Xdebug may not be built for that version or architecture (e.g., only available for PHP 7.4+). Use a different version or file an issue on GitHub. |
| VS Code says "Listening for Xdebug" but nothing happens | Open a page in your browser that hits the code. Xdebug only connects when a request is in progress. |
| Debugger is slow or laggy | Xdebug adds overhead. This is normal. If it's too slow, consider using logging instead of live debugging for large codebases. |
| Multiple sites on different PHP versions, only one debugged | Xdebug only works for sites on the enabled PHP version. If you have sites on PHP 8.1 and 8.3, only sites on the enabled version will trigger breakpoints. Enable Xdebug on the version you're debugging. |

## Where to go next

Now that you can debug your PHP code, head to [15 — Shell integration](15-shell-integration.md) to run the same PHP version from your terminal that your project uses.
