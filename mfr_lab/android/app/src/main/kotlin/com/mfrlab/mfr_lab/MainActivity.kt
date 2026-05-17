package com.mfrlab.mfr_lab

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Prevent app restart when launched from home screen icon
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_LAUNCHER)) {
            if (!isTaskRoot) {
                finish()
                return
            }
        }
        super.onCreate(savedInstanceState)
    }
}
