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
    
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                // 1. Auto-inject missing namespace fields for older dependency versions
                if (android.namespace == null) {
                    android.namespace = project.group.toString()
                }
                
                // 2. Automatically strip illegal package attributes from plugin manifests during build
                android.sourceSets.forEach { sourceSet ->
                    val manifestFile = project.file(sourceSet.manifest.srcFile)
                    if (manifestFile.exists()) {
                        val text = manifestFile.readText()
                        if (text.contains("package=\"")) {
                            manifestFile.writeText(text.replace(Regex("package=\"[^\"]*\""), ""))
                        }
                    }
                }
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
