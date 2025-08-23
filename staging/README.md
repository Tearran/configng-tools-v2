# Module SDK & Development Guide: configng-v2

This guide covers the **practical SDK** for contributing modules to configng-v2.  

📋 **For project roadmap and milestone tracking, see [ROADMAP.md](../ROADMAP.md)**  

---

## Directory Structure

- `staging/` — Work-in-progress modules (development area).
- `src/` — Develomnet modules (after promotion).
- `lib/` — Assembled Bash libraries (for the final framework).
- `SDK/` — Scripts for scaffolding, checking, and automating the SDK.
- `modules_browsers/` - Protoype GUI emplementaions to interact with modules metadata

---

## Module Contribution SDK

1. **Scaffold a Module**
   - run
   ```sh
   ./SDK/00_start_here.sh <modulename>
   ```
   - Creates `staging/<modulename>.sh`, and `staging/<modulename>.conf`.

3. **Develop**
   - Write module logic in `.sh` (use **tabs** for indentation).
   - updade the _about_<modulename> help message
   - Fill out `.conf` (flat key=value).

4. **Verify & Test**
   - Manually test your module in `staging/`.
   - Run:
     ```sh
     ./SDK/10_validate_module.sh
     ```
   - fix invalid/missing if any
     
5. **Promote modules to `./src`**
   - Move ready modules from `staging/` to `src/` as defined in `.conf`.
   - run
     ```sh
     ./SDK/20_promote_module.sh
     ```
6. **Generate Documents from promoted metadata**
   - run
     ```sh
     ./SDK/30_docstring.sh
     ```
7. **Consolidate modules**
   - Flatten `src/` modules into `lib/` as needed for releases.
   - run
     ```sh
     ./SDK/40_consolidate_module.sh
     ```
8. **Generate json object**
   - json object from consolidated modules array
   - Used for:
      - ./modules_browsers/README.md
      - ./docs/index.html
      - ./lib/armbian-config/config.jobs.json
   - run
     ```sh
      ./SDK/50_array_to_json.sh
     ```
---

## Best Practices

- **Tabs for indentation** in Bash code.
- **Keep configs flat:** Only key=value pairs in `.conf`.
- **Each module must be:**
  - Runnable as a script (CLI/test).
  - Sourceable by the framework (TUI/automation).
- **Minimal dependencies:** Document any required module dependencies.
- **Clear help output:** Each module must support `--help`.

---

For more details, see the main [README.md](../README.md) or ask in project discussions.
