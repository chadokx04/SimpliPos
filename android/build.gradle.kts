allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Some plugins (e.g. flutter_native_splash) ship an Android module whose
    // own build.gradle still hardcodes an older compileSdk than this app's,
    // which breaks against newer AndroidX transitive dependencies that
    // require compileSdk >= 33. Force every module to compile against the
    // same SDK as the app itself rather than whatever each plugin declared.
    // Registered here, before evaluationDependsOn below forces some modules
    // to evaluate early — afterEvaluate throws if added post-evaluation.
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileSdkVersion(36)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
