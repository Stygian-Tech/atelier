plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "diy.atelier.appui"
    compileSdk = 37
    defaultConfig { minSdk = 29 }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    api(project(":core"))
    implementation(project(":contracts"))
    implementation(project(":persistence"))
    implementation(project(":collaboration"))
    implementation(project(":design"))
    implementation(project(":editor"))
    implementation(platform(libs.compose.bom))
    // The five application modules subclass AtelierActivity, so its AndroidX
    // superclass is part of this module's public compile contract.
    api(libs.activity.compose)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
}
