// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package com.tailscale.ipn

import android.content.Intent
import org.junit.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

class BootReceiverTest {
  private val app = mock<UninitializedApp>()

  private fun ready() {
    whenever(app.isStartOnBootEnabled()).thenReturn(true)
    whenever(app.isAbleToStartVPN()).thenReturn(true)
  }

  @Test
  fun bootStartsAuthorizedVpn() {
    ready()
    startOnBoot(app, Intent.ACTION_BOOT_COMPLETED) { true }
    verify(app).startVPN()
  }

  @Test
  fun updateStartsAuthorizedVpn() {
    ready()
    startOnBoot(app, Intent.ACTION_MY_PACKAGE_REPLACED) { true }
    verify(app).startVPN()
  }

  @Test
  fun disabledAutoStartDoesNotConnect() {
    ready()
    whenever(app.isStartOnBootEnabled()).thenReturn(false)
    startOnBoot(app, Intent.ACTION_BOOT_COMPLETED) { error("Must not request consent") }
    verify(app, never()).startVPN()
  }

  @Test
  fun missingLoginDoesNotConnect() {
    ready()
    whenever(app.isAbleToStartVPN()).thenReturn(false)
    startOnBoot(app, Intent.ACTION_BOOT_COMPLETED) { error("Must not request consent") }
    verify(app, never()).startVPN()
  }

  @Test
  fun missingVpnConsentDoesNotConnect() {
    ready()
    startOnBoot(app, Intent.ACTION_BOOT_COMPLETED) { false }
    verify(app, never()).startVPN()
  }

  @Test
  fun unrelatedOrMissingActionDoesNotConnect() {
    for (action in listOf(null, Intent.ACTION_SCREEN_ON, "com.example.BOOT_COMPLETED")) {
      startOnBoot(app, action) { error("Must not request consent") }
    }
    verify(app, never()).startVPN()
  }
}
