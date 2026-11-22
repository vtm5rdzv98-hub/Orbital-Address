# Firmware and bench setup

The browser demo runs independently of the hardware. For a bench build, activate an ESP-IDF toolchain and work from the repository root:

```sh
cp main/app_config.h.example main/app_config.h
# Fill in the lab Wi-Fi credentials, bridge address, and board overrides.
idf.py set-target esp32s3
idf.py build
```

`main/app_config.h` is ignored by Git. Check the pin assignments in [app_config_defaults.h](../main/app_config_defaults.h) against your board. Set the bridge's UDP bind address and port for the bench network explicitly. For signed packets, configure the same private HMAC secret on the bridge and on the device. See [signed telemetry](../telemetry-bridge/TELEMETRY_PROVENANCE.md) and [operator authentication](../telemetry-bridge/AUTHENTICATION.md).

The firmware normally emits v4 measurements and uses v6 in debug mode. The bridge also reads older layouts for compatibility. See the [packet reference](../TELEMETRY_PACKET_V1.md) and [debug mode guide](../DEBUG_MODE.md).

The [INA226 bench target](../ina226-load-test/README.md) is a separate ESP-IDF project for testing current and voltage acquisition. It uses its own ignored configuration header.

## Portable C checks

From the repository root, with a C compiler:

```sh
test_dir=$(mktemp -d)
cc -std=c11 -Wall -Wextra -Werror -I main \
  main/peripheral_sensor_math.c test/peripheral_sensor_math_test.c \
  -lm -o "$test_dir/peripherals"
"$test_dir/peripherals"

cc -std=c11 -Wall -Wextra -Werror -I test/stubs -I pass -I main \
  pass/telemetry_packet_v3.c pass/telemetry_packet_v4.c \
  test/telemetry_packet_v4_test.c -o "$test_dir/packets"
"$test_dir/packets"
```

The INA226 project documents its own portable protocol test. Board validation also requires an ESP-IDF cross-build and a bench check of sensor wiring, scaling, and control behavior.
