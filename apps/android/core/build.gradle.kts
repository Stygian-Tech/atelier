plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "diy.atelier.core"
    compileSdk = 35

    defaultConfig { minSdk = 29 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Use the public AGP 9 DSL to avoid the legacy source-set accessor's invalid cast.
extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    sourceSets.getByName("test").resources.directories.add(
        rootProject.file("../../packages/contracts/fixtures").path,
    )
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies { testImplementation(libs.junit) }
