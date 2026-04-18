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

    // Some Flutter plugins (receive_sharing_intent, audio_session,
    // desktop_drop, …) still declare Java 1.8 inside their own
    // android { compileOptions } block, which collides with the app's
    // Kotlin 17. We mutate each subproject's android extension +
    // every JavaCompile / KotlinCompile task in afterEvaluate, via
    // reflection so we don't need to pin the Kotlin Gradle Plugin
    // classpath at the root.
    afterEvaluate {
        // 1. Rewrite the android { compileOptions { … } } extension
        //    in-place — this is what the plugin uses to initialise
        //    both JavaCompile source/target AND KotlinCompile jvmTarget
        //    at task-configure time.
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val compileOpts = androidExt.javaClass.methods
                .firstOrNull { it.name == "getCompileOptions" && it.parameterCount == 0 }
                ?.invoke(androidExt)
            if (compileOpts != null) {
                fun setJavaVersion(setter: String) {
                    compileOpts.javaClass.methods
                        .firstOrNull { it.name == setter && it.parameterTypes.size == 1 && it.parameterTypes[0] == JavaVersion::class.java }
                        ?.invoke(compileOpts, JavaVersion.VERSION_17)
                }
                setJavaVersion("setSourceCompatibility")
                setJavaVersion("setTargetCompatibility")
            }
            // Android kotlinOptions { jvmTarget = "17" }
            val kotlinExt = extensions.findByName("kotlin")
                ?: androidExt.javaClass.methods
                    .firstOrNull { it.name == "getKotlinOptions" }
                    ?.invoke(androidExt)
            if (kotlinExt != null) {
                kotlinExt.javaClass.methods
                    .firstOrNull { it.name == "setJvmTarget" && it.parameterTypes.size == 1 }
                    ?.invoke(kotlinExt, "17")
            }
        }
        // 2. Belt + suspenders — force on every configured task too.
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.matching {
            it.name.startsWith("compile") && it.name.endsWith("Kotlin")
        }.configureEach {
            val ko = this.javaClass.methods
                .firstOrNull { it.name == "getKotlinOptions" }
                ?.invoke(this)
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
