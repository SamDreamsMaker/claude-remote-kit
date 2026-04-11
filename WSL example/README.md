# Test Environment (WSL2)

Test the Claude Agent Kit locally using Windows Subsystem for Linux.

## Quick Start

1. Open PowerShell **as Administrator** in this folder
2. Run:
   ```powershell
   .\setup-test.ps1
   ```
3. If WSL/Ubuntu needs installing, follow the prompts and reboot if asked
4. Once ready, enter the test environment:
   ```powershell
   wsl -d Ubuntu
   ```
5. Inside WSL, test the full installation:
   ```bash
   ~/01-install.sh
   ```

## After editing scripts

Re-run the setup to copy updated scripts into WSL:
```powershell
.\setup-test.ps1
```

## Reset from scratch

```powershell
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```
Then run `.\setup-test.ps1` again.

## Known WSL limitations

- `screen` may require: `sudo mkdir -p /run/screen && sudo chmod 777 /run/screen`
- Localhost networking works differently — OAuth tunnel test not needed
