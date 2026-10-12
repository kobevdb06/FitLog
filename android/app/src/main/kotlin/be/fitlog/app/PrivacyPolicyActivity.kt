package be.fitlog.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabsIntent

/**
 * What Health Connect opens when someone taps FitLog's privacy policy on its
 * permission screen: the policy itself, over Health Connect.
 *
 * It used to open the app, which may first ask for a pincode and then shows
 * its home screen - not what anyone tapped. Health Connect also wants an
 * activity like this before it lets the app ask for anything at all, so it
 * stays even for someone who never taps the link.
 *
 * No Flutter here: the page opens in a Custom Tab (or the browser, on a phone
 * without one) and this activity is gone before it is ever drawn. Back from
 * the page is back in Health Connect.
 */
class PrivacyPolicyActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = Uri.parse(PRIVACY_URL)
        try {
            CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(this, uri)
        } catch (error: ActivityNotFoundException) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
            } catch (none: ActivityNotFoundException) {
                // Nothing on the phone opens a web page; there is nothing
                // left to show.
            }
        }
        finish()
    }

    companion object {
        /** The same address as `kPrivacyUrl` in lib/features/chat/data/links.dart. */
        const val PRIVACY_URL = "https://kobevdb06.github.io/FitLog/privacy.html"
    }
}
