import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.isFile) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
// Use one complete source; never silently mix local and CI credentials.
val signingEnvironment = mapOf(
    "storeFile" to "ROUTINA_KEYSTORE_FILE",
    "storePassword" to "ROUTINA_KEYSTORE_PASSWORD",
    "keyAlias" to "ROUTINA_KEY_ALIAS",
    "keyPassword" to "ROUTINA_KEY_PASSWORD",
)
val useSigningEnvironment = signingEnvironment.values.any { System.getenv(it) != null }
val hasReleaseSigning = useSigningEnvironment || signingPropertiesFile.isFile
val allowUnsignedAudit = System.getenv("ROUTINA_ALLOW_UNSIGNED_RELEASE") == "true"

fun signingValue(key: String): String {
    val value = if (useSigningEnvironment) System.getenv(signingEnvironment.getValue(key))
        else signingProperties.getProperty(key)
    require(!value.isNullOrBlank()) {
        "Missing release signing setting: $key. See docs/ANDROID_SIGNING.md."
    }
    return value
}

android {
    namespace = "com.example.routina"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // DECISION REQUIRED: owner must approve the public identity before distribution.
        // Changing this ID creates a separate app and does not migrate local data.
        applicationId = "com.example.routina"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs.create("release") {
            storeFile = rootProject.file(signingValue("storeFile"))
            require(storeFile!!.isFile) { "Release keystore file does not exist." }
            storePassword = signingValue("storePassword")
            keyAlias = signingValue("keyAlias")
            require(!keyAlias.equals("androiddebugkey", ignoreCase = true)) {
                "Android debug signing is forbidden for release."
            }
            keyPassword = signingValue("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Enforce this only for release task graphs so debug development remains available.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        check(hasReleaseSigning || allowUnsignedAudit) {
            "Release signing required. Configure owner credentials; " +
                "ROUTINA_ALLOW_UNSIGNED_RELEASE=true is for local audit ONLY. " +
                "See docs/ANDROID_SIGNING.md."
        }
    }
}

flutter {
    source = "../.."
}
