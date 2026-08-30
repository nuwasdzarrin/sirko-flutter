allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build output diarahkan ke direktori TANPA SPASI.
// Alasan: path proyek ada di "C:\Users\WINDOWS 11\..." — spasi pada "WINDOWS 11"
// membuat Flutter Gradle plugin gagal membuat folder flutter_assets di Windows
// (path terpecah jadi "C:\Users\WINDOWS"). Solusi lintas-mesin: pindahkan proyek
// ke path tanpa spasi. Sementara, relokasikan build ke C:/fbuild/sirko.
val newBuildDir = file("C:/fbuild/sirko")
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    project.layout.buildDirectory.set(newBuildDir.resolve(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
