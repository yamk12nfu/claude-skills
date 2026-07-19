# browser-use CLI Command Reference

Binary: `/Users/makinokaedenari/.browser-use-env/bin/browser-use`

## Global Options

| Option | Description |
|---|---|
| `--headed` | Show browser window (visible mode) |
| `--profile [NAME]` | Use real Chrome with profile (default: "Default") |
| `--session NAME` | Use/resume a named session (persistent state) |
| `--json` | Output in JSON format |
| `--cdp-url URL` | Connect to an existing browser via CDP |
| `--connect` | Connect to an already-running browser |

## Navigation

```bash
browser-use open <url>                    # Navigate to URL
browser-use back                          # Go back in history
browser-use close                         # Close browser and stop daemon
browser-use close-tab                     # Close current tab
browser-use switch <tab_index>            # Switch to tab by index
```

## Interaction

```bash
browser-use click <index>                 # Click element by state index
browser-use click <x> <y>                 # Click by coordinates
browser-use type <text>                   # Type text (into focused element)
browser-use input <index> <text>          # Type into specific element
browser-use hover <index>                 # Hover over element
browser-use dblclick <index>              # Double-click element
browser-use rightclick <index>            # Right-click element
browser-use select <index> <value>        # Select dropdown option
browser-use scroll <direction>            # Scroll: up, down, left, right
browser-use keys <key>                    # Keyboard: Enter, Tab, Escape, Control+a, etc.
browser-use upload <index>                # Upload file to file input
browser-use wait <condition>              # Wait for condition
```

## Information Retrieval

```bash
browser-use state                         # Get page state: URL, title, interactive elements with indices
browser-use screenshot [path] [--full]    # Take screenshot (saves to path or outputs base64)
browser-use extract "<query>"             # Extract data using LLM (natural language query)
browser-use eval "<javascript>"           # Execute JavaScript and return result
browser-use get <info>                    # Get specific info (url, title, cookies, etc.)
browser-use cookies                       # Cookie operations
```

## Advanced

```bash
browser-use python "<code>"           # Execute Python in a persistent namespace (--file FILE / --reset / --vars)
browser-use sessions                  # List active browser sessions
browser-use tunnel <port>             # Expose localhost via Cloudflare tunnel (tunnel list / tunnel stop <port> / --all)
browser-use cloud connect             # Provision cloud browser and connect (cloud login/logout, v2/v3 REST passthrough)
browser-use profile <args>            # profile-use passthrough
```

## Key Patterns

### Element Targeting
`browser-use state` returns interactive elements with numeric indices. Use these indices for click, input, hover, etc.

### Session Persistence
`--session <name>` keeps browser state between commands — login cookies, tabs, and page state persist.

### Full Page Screenshot
`browser-use screenshot path.png --full` captures the entire scrollable page.
