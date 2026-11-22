# Orbital Address v1.0.0 — Portfolio Demo

This is the first curated, reproducible **Orbital Address** portfolio release: the web-based telemetry, diagnostics, recording, and operator-control platform developed for the UCF KnightEPS CubeSat electrical power system prototype.

## Included

- Browser dashboard for power-system monitoring and network/link diagnostics.
- Node.js bridge for versioned UDP telemetry decoding, HTTP APIs, and Server-Sent Events.
- SQLite-backed telemetry recording, run inspection, and CSV export.
- Role-aware operator interface with controlled I²C register access and conditional bench sequences.
- CAD-derived Three.js digital twin with component-level inspection.
- Local viewer and operator demonstrations using a loopback-only UDP **device simulator**.
- Test suites for the bridge, link tools, digital-twin code, and portable firmware components.

## Run the portfolio demo

Requires Node.js 22 or 24, npm, and Bash.

~~~bash
git clone https://github.com/vtm5rdzv98-hub/Orbital-Address.git
cd Orbital-Address
npm ci --prefix telemetry-bridge
bash tools/demo.sh
~~~

For the authenticated operator workflow, use:

~~~bash
bash tools/demo.sh --operator
~~~

Open **http://127.0.0.1:8090**, select Dashboard, and use the temporary credentials printed by the launcher. The operator mode also prints a separate command token. Press Ctrl+C to stop and delete temporary demonstration state.

Read the [operator walkthrough](../docs/operator-demo.md) or the [README](../README.md) for details.

## Verification scope

The local demo exercises real application code and network paths, but **the telemetry values and device responses in the demonstration are simulated**. Automated tests check software behavior; they do not establish physical sensor accuracy, battery safety, flight readiness, or production uptime.

The physical EPS prototype was tested separately as part of the collaborative KnightEPS senior-design project. Refer to the team's presentation and supporting bench records for those measurements.

This release is a portfolio snapshot, **not a claim that this exact commit is deployed at orbitaladdress.com** and **not a flight-qualified hardware release**. Production hardware-control access remains separately protected.

## Project and credits

Orbital Address is the ground-side software for KnightEPS at the University of Central Florida. Itzjac Lechtman developed cloud and GUI portions; Jaden Adkins worked on firmware and MCU telemetry; William Garland contributed power management, battery systems, and PCBs; and Liam Magee contributed MCU hardware, regulators, and PCBs. The integrated prototype was a team effort.

See [LICENSE](../LICENSE) and upstream notices in the repository for source-code licensing. Project imagery and digital-twin assets may have separate reuse considerations.

**Live site:** https://orbitaladdress.com/#home

**Team presentation:** https://youtu.be/O13I94AdMXs
