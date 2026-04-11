# Test Environment (WSL2)

Test the Claude Remote Kit locally on Windows 11 using WSL2.
The test uses the **exact same one-liner** as a real server install.

## Quick Start

1. Open PowerShell **as Administrator** in this folder
2. Run:
   ```powershell
   .\setup-test.ps1
   ```
3. If WSL/Ubuntu needs installing, follow the prompts and reboot if asked
4. Enter the test environment:
   ```powershell
   wsl -d Ubuntu
   ```
5. Run the one-liner installer:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/SamDreamsMaker/claude-remote-kit/main/01-install.sh -o /tmp/install.sh && bash /tmp/install.sh
   ```
6. Then the Telegram setup:
   ```bash
   ~/claude-remote-kit/02-install-telegram.sh
   ```

## Reset from scratch

```powershell
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```
Then run `.\setup-test.ps1` again.

## Known WSL limitations

- `screen` may require: `sudo mkdir -p /run/screen && sudo chmod 777 /run/screen` (handled by 01-install.sh)
- Localhost networking works differently — OAuth via interactive login handles it
