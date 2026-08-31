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
            if (android != null && name != "app") {
                // Set compileSdk to 36 for plugin libraries
                try {
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    setCompileSdk.invoke(android, 36)
                } catch (e: Exception) {
                    try {
                        val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        compileSdkVersion.invoke(android, 36)
                    } catch (e2: Exception) {
                        // ignore
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
                        }
                    }
                } catch (manifestErr: Exception) {
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
                        }
                    }
                } catch (nsErr: Exception) {
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
