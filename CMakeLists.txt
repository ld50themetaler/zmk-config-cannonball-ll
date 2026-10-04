# Copyright (c) 2026
# SPDX-License-Identifier: MIT

if (CONFIG_SHIELD_CANNONBALL_LL)
    target_sources(app PRIVATE boards/shields/Cannonball_LL/ble_profile_led.c)
endif()
