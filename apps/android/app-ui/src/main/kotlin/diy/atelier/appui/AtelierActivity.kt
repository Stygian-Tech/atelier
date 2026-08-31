package diy.atelier.appui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import diy.atelier.core.AppProduct
import diy.atelier.design.AtelierTheme

abstract class AtelierActivity : ComponentActivity() {
    protected abstract val product: AppProduct

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AtelierTheme(product = product) {
                AtelierNativeApp(product = product)
            }
        }
    }
}
