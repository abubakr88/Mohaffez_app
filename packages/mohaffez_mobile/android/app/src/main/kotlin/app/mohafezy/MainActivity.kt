package app.mohafezy

import android.content.pm.ApplicationInfo
import android.os.Bundle
import com.google.firebase.appcheck.AppCheckProviderFactory
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
            if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)
                getDebugProviderFactory() ?: PlayIntegrityAppCheckProviderFactory.getInstance()
            else
                PlayIntegrityAppCheckProviderFactory.getInstance()
        )
    }

    // Loads DebugAppCheckProviderFactory via reflection so the import
    // never appears in release — avoids compile-time resolution failure.
    private fun getDebugProviderFactory(): AppCheckProviderFactory? {
        return try {
            Class.forName("com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory")
                .getMethod("getInstance")
                .invoke(null) as AppCheckProviderFactory
        } catch (e: Exception) {
            null
        }
    }
}
