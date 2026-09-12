plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
}

val aquraUrl = providers.gradleProperty("aquraUrl")
    .orElse("https://aqura-frontend.vercel.app/mobile-interface")

android {
    namespace = "com.aqura.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.aqura.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "AQURA_URL", "\"${aquraUrl.get()}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.activity:activity:1.10.1")
    implementation("androidx.webkit:webkit:1.13.0")
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-messaging")
}
