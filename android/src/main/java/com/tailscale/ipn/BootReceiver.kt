// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package com.tailscale.ipn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService

/** Starts the VPN after unlock, once login and VPN consent have been completed. */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    startOnBoot(UninitializedApp.get(), intent?.action) { VpnService.prepare(context) == null }
  }
}

internal fun startOnBoot(app: UninitializedApp, action: String?, hasVpnConsent: () -> Boolean) {
  if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
    return
  }
  if (app.isStartOnBootEnabled() && app.isAbleToStartVPN() && hasVpnConsent()) {
    app.startVPN()
  }
}
