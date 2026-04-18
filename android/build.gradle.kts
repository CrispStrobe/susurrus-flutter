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

    // Some Flutter plugins (receive_sharing_intent, audio_session, …) still
    // declare Java 1.8 in their own build.gradle, which collides with the
    // app's Kotlin 17. Register the JVM-target coercion BEFORE the
    // evaluationDependsOn block below so the afterEvaluate hook is in
    // place when those subprojects eagerly evaluate.
    afterEvaluate {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.matching {
            it.name.startsWith("compile") && it.name.endsWith("Kotlin")
        }.configureEach {
            // Set jvmTarget reflectively so we don't need to pin the
            // kotlin-gradle-plugin classpath at the root level.
            val ko = this.javaClass.methods.firstOrNull { it.name == "getKotlinOptions" }?.invoke(this)
            if (ko != null) {
                ko.javaClass.methods
                    .firstOrNull { it.name == "setJvmTarget" && it.parameterTypes.size == 1 }
                    ?.invoke(ko, "17")
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
