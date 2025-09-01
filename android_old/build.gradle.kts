buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.3.2") // Version compatible Java 17
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
        classpath("com.google.gms:google-services:4.4.1") // Version mise à jour
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}