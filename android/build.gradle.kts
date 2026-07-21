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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureProject: Project.() -> Unit = {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByName("android")
            if (android != null) {
                // Set compileSdk to 36
                try {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    setCompileSdk.invoke(android, 36)
                } catch (e: Exception) {
                    try {
                        val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        compileSdkVersion.invoke(android, 36)
                    } catch (e2: Exception) {
                        println("Không thể ép compileSdk cho $name: ${e2.message}")
                    }
                }

                // Extract package name from manifest to use as namespace and strip the package attribute from manifest
                var manifestPackage: String? = null
                try {
                    val manifestFile = File(projectDir, "src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val match = Regex("""package="([^"]+)"""").find(manifestText)
                        if (match != null) {
                            manifestPackage = match.groupValues[1]
                        }
                        
                        // Strip package attribute to prevent AGP 8+ manifest processing errors
                        if (manifestText.contains("package=")) {
                            val updatedText = manifestText.replace(Regex("""package="[^"]+""""), "")
                            manifestFile.writeText(updatedText)
                            println("[Namespace-Fix] Stripped package attribute from ${name}'s AndroidManifest.xml")
                        }
                    }
                } catch (manifestErr: Exception) {
                    println("[Namespace-Fix] Failed to process AndroidManifest.xml for $name: ${manifestErr.message}")
                }

                // Patch google_mobile_ads configurations.all for Gradle 8 compatibility
                if (name == "google_mobile_ads") {
                    try {
                        val buildFile = File(projectDir, "build.gradle")
                        if (buildFile.exists()) {
                            val text = buildFile.readText()
                            if (text.contains("configurations.all")) {
                                buildFile.writeText(text.replace("configurations.all", "configurations"))
                                println("[Gradle-Fix] Patched google_mobile_ads build.gradle for Gradle 8 compatibility")
                            }
                        }
                    } catch (e: Exception) {
                        println("[Gradle-Fix] Failed to patch google_mobile_ads build.gradle: ${e.message}")
                    }
                }

                // Automatic namespace injector for older plugins to prevent AGP 8+ namespace failures
                try {
                    val methods = android.javaClass.methods
                    val hasGetNamespace = methods.any { it.name == "getNamespace" }
                    val hasSetNamespace = methods.any { it.name == "setNamespace" && it.parameterTypes.size == 1 && it.parameterTypes[0] == String::class.java }
                    if (hasGetNamespace && hasSetNamespace) {
                        val getNamespace = android.javaClass.getMethod("getNamespace")
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        val currentNamespace = getNamespace.invoke(android)
                        if (currentNamespace == null || (currentNamespace as String).trim().isEmpty()) {
                            val cleanName = name.replace(Regex("[^a-zA-Z0-9_]"), "")
                            val fallbackNamespace = manifestPackage ?: "com.txa.$cleanName"
                            setNamespace.invoke(android, fallbackNamespace)
                            println("[Namespace-Fix] Set namespace for $name to $fallbackNamespace")
                        }
                    }
                } catch (nsErr: Exception) {
                    println("[Namespace-Fix] Failed to adjust namespace for $name: ${nsErr.message}")
                }
            }
        }
    }

    if (state.executed) {
        configureProject()
    } else {
        afterEvaluate {
            configureProject()
        }
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
