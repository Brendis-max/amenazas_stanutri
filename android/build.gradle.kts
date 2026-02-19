buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Solo dejamos el de google-services aquí si el plugin del settings no lo toma
        classpath("com.google.gms:google-services:4.4.2")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}