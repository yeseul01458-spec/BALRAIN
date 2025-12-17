plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.balrain"   // ← 너의 namespace로 맞춰도 됨
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.balrain"  // ← 너의 appId로
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        debug {
            // 디버그는 축소 끔 (이전 오류 방지)
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // 릴리스에서만 축소
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Java 컴파일 타겟
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Kotlin 컴파일러 JDK 설정 (kts에서 안전)
kotlin {
    jvmToolchain(17)
}

// Flutter가 대부분의 의존성을 주입하므로 일반적으로 비워둠
dependencies {
}

