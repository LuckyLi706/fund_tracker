allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroidTestOptions = { p: Project ->
        if (p.hasProperty("android")) {
            val android = p.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                android.testOptions.unitTests.isIncludeAndroidResources = false
            }
        }
    }

    if (project.state.executed) {
        configureAndroidTestOptions(project)
    } else {
        project.afterEvaluate {
            configureAndroidTestOptions(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
