/*
 * Copyright (c) 2026
 * SPDX-License-Identifier: MIT
 *
 * Controls onboard blue LED to display active BLE profile:
 * - Profile 1-4 (index 0-3): 1-4 short blinks (150ms ON / 150ms OFF)
 * - Profile 5   (index 4):   1 long blink    (500ms ON / 200ms OFF)
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/init.h>
#include <zmk/ble.h>
#include <zmk/event_manager.h>
#include <zmk/events/ble_active_profile_changed.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(ble_profile_led, CONFIG_ZMK_LOG_LEVEL);

#if DT_NODE_EXISTS(DT_NODELABEL(led2))
static const struct gpio_dt_spec blue_led = GPIO_DT_SPEC_GET(DT_NODELABEL(led2), gpios);
#endif

#if DT_NODE_EXISTS(DT_NODELABEL(led0))
static const struct gpio_dt_spec red_led = GPIO_DT_SPEC_GET(DT_NODELABEL(led0), gpios);
#endif

#if DT_NODE_EXISTS(DT_NODELABEL(led1))
static const struct gpio_dt_spec green_led = GPIO_DT_SPEC_GET(DT_NODELABEL(led1), gpios);
#endif

static K_SEM_DEFINE(ble_led_sem, 0, 1);
static volatile uint8_t g_profile_index = 0;

static void ble_led_thread(void *p1, void *p2, void *p3) {
    ARG_UNUSED(p1);
    ARG_UNUSED(p2);
    ARG_UNUSED(p3);

#if DT_NODE_EXISTS(DT_NODELABEL(led2))
    if (!device_is_ready(blue_led.port)) {
        LOG_ERR("Blue LED device not ready");
        return;
    }
#endif

    while (1) {
        k_sem_take(&ble_led_sem, K_FOREVER);

#if DT_NODE_EXISTS(DT_NODELABEL(led2))
        uint8_t profile = g_profile_index;
        int profile_num = (int)profile + 1;
        int long_blinks = profile_num / 5;
        int short_blinks = profile_num % 5;

        LOG_INF("BLE Profile changed: %d (long: %d, short: %d)", profile_num, long_blinks, short_blinks);

        // Ensure LED is OFF initially
        gpio_pin_set_dt(&blue_led, 0);

        // Long blinks: 1 blink = 5 devices (500ms ON / 200ms OFF)
        for (int i = 0; i < long_blinks; i++) {
            gpio_pin_set_dt(&blue_led, 1);
            k_msleep(500);
            gpio_pin_set_dt(&blue_led, 0);
            k_msleep(200);
        }

        if (long_blinks > 0 && short_blinks > 0) {
            k_msleep(150);
        }

        // Short blinks: 1 blink = 1 device (150ms ON / 150ms OFF)
        for (int i = 0; i < short_blinks; i++) {
            gpio_pin_set_dt(&blue_led, 1);
            k_msleep(150);
            gpio_pin_set_dt(&blue_led, 0);
            k_msleep(150);
        }

        // Final OFF
        gpio_pin_set_dt(&blue_led, 0);
#endif
    }
}

K_THREAD_DEFINE(ble_profile_led_tid, 1024, ble_led_thread, NULL, NULL, NULL,
                K_PRIO_PREEMPT(10), 0, 500);

static int ble_profile_listener(const zmk_event_t *eh) {
    const struct zmk_ble_active_profile_changed *ev = as_zmk_ble_active_profile_changed(eh);
    if (ev == NULL) {
        return ZMK_EV_EVENT_BUBBLE;
    }

    g_profile_index = ev->index;
    k_sem_give(&ble_led_sem);

    return ZMK_EV_EVENT_BUBBLE;
}

ZMK_LISTENER(ble_profile_led, ble_profile_listener);
ZMK_SUBSCRIPTION(ble_profile_led, zmk_ble_active_profile_changed);

static int ble_profile_led_init(void) {
#if DT_NODE_EXISTS(DT_NODELABEL(led2))
    if (device_is_ready(blue_led.port)) {
        gpio_pin_configure_dt(&blue_led, GPIO_OUTPUT_INACTIVE);
    }
#endif

#if DT_NODE_EXISTS(DT_NODELABEL(led0))
    if (device_is_ready(red_led.port)) {
        gpio_pin_configure_dt(&red_led, GPIO_OUTPUT_INACTIVE);
    }
#endif

#if DT_NODE_EXISTS(DT_NODELABEL(led1))
    if (device_is_ready(green_led.port)) {
        gpio_pin_configure_dt(&green_led, GPIO_OUTPUT_INACTIVE);
    }
#endif

    LOG_INF("BLE profile LED indicator initialized");
    return 0;
}

SYS_INIT(ble_profile_led_init, APPLICATION, CONFIG_APPLICATION_INIT_PRIORITY);
