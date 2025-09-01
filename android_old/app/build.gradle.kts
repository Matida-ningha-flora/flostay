plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // 🔥 applique ici
}

android {
    namespace = "com.example.flostay" // change si ton appId est différent
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.flostay" // 🔥 doit matcher ton google-services.json
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
}

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17 // Java 17
        targetCompatibility = JavaVersion.VERSION_17 // Java 17
    }

    kotlinOptions {
        jvmTarget = "17" // Java 17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }


flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.23")
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
}