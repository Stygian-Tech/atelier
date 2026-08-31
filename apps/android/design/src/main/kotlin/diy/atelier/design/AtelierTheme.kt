package diy.atelier.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import diy.atelier.core.AppProduct

object AtelierColors {
    val Paper = Color(0xFFF9F4E8)
    val Ink = Color(0xFF292623)
    val Coral = Color(0xFFE8584F)
    val Cyan = Color(0xFF35A8B8)
    val Yellow = Color(0xFFF5C241)
    val Green = Color(0xFF599657)

    fun accent(product: AppProduct): Color = when (product) {
        AppProduct.ATELIER, AppProduct.MAIL -> Coral
        AppProduct.NOTES -> Yellow
        AppProduct.CALENDAR -> Cyan
        AppProduct.TASKS -> Green
    }
}

@Composable
fun AtelierTheme(
    product: AppProduct,
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val accent = AtelierColors.accent(product)
    val colors: ColorScheme = if (darkTheme) {
        darkColorScheme(primary = accent, tertiary = AtelierColors.Cyan)
    } else {
        lightColorScheme(
            primary = accent,
            secondary = AtelierColors.Cyan,
            tertiary = AtelierColors.Yellow,
            background = AtelierColors.Paper,
            onBackground = AtelierColors.Ink,
            surface = AtelierColors.Paper,
            onSurface = AtelierColors.Ink,
        )
    }
    MaterialTheme(colorScheme = colors, content = content)
}
